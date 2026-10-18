"""SMS and email checks: recorded consent, unsubscribe, STOP handling."""
import re
from dataclasses import dataclass

from .common import Rule, SOURCE_EXTS, non_doc_files

DOMAIN = "messaging"
MANIFESTS = (
    "package.json", "Cargo.toml", "requirements.txt", "pyproject.toml",
    "composer.json", "go.mod", "deno.json",
)
EMAIL_SENDER = (
    r"nodemailer|@sendgrid/mail|sendgrid\.com|api\.resend\.com"
    r"|new Resend\(|from ['\"]resend['\"]|postmark|mailgun|sib-api-v3"
    r"|sendinblue|brevo|mailjet|mandrill|client-ses|SendEmailCommand"
    r"|smtplib|use lettre|lettre::|PHPMailer|mailchimp"
)
SMS_SENDER = (
    r"twilio|vonage|nexmo|messagebird|sns\.publish|@aws-sdk/client-sns"
    r"|PublishCommand|ovh.{0,20}sms|plivo|sinch|clicksend|smsapi"
    r"|sendTransacSms|telnyx|infobip|africastalking"
)
CONSENT_STORED = (
    r"consent(?:ed)?_?(?:at|date|ts|timestamp|source|status|given|version"
    r"|text)|opt_?in_?(?:at|date|source|ts|timestamp)|opted_?in|double_?opt"
    r"|marketing_consent|has_consented|sms_consent|email_consent"
)
CONSENT_CHECKED = (
    r"consent|opt_?in|opted|subscribed|unsubscrib|suppress|allowed_to_contact"
)
UNSUBSCRIBE = r"unsubscrib|d[ée]sinscri"
OPT_OUT_STORED = (
    r"opt_?out|unsubscribed|stopped|suppress|blocklist|do_not_(?:contact|text)"
)
TRANSACTIONAL = re.compile(
    r"contact|reset|verif|otp|password|confirm|receipt|invoice|welcome"
    r"|magic|login|signin|2fa|mfa|booking|reservation", re.I)
MARKETING = re.compile(
    r"newsletter|campaign|subscriber|mailing|broadcast|promo|marketing"
    r"|bulk|audience|relance|blast", re.I)
TRANSACTIONAL_NOTE = " (only transactional senders found: confirm no marketing)"
TEST_PATH = re.compile(
    r"(?:^|/)(?:tests?|__tests__|spec)/|\.(?:test|spec)\.|Test\.php$", re.I)
BULK_STORAGE = (
    r"subscriber|newsletter|mailing[_ ]?list|contact_list|audience"
)


def sender_files(project):
    files = project.with_ext(*SOURCE_EXTS) + project.named(*MANIFESTS)
    return [p for p in files if not TEST_PATH.search(project.rel(p))]


def _sends(project, path):
    return project.has(EMAIL_SENDER, [path]) or project.has(SMS_SENDER, [path])


def _kind(project, path):
    rel = project.rel(path)
    if MARKETING.search(rel):
        return "marketing"
    return "transactional" if TRANSACTIONAL.search(rel) else "unknown"


def _severity(project, senders):
    """FAIL unless a sender looks transactional and nothing bulk exists."""
    code = [p for p in senders if p.suffix.lower() in SOURCE_EXTS] or senders
    kinds = {_kind(project, p) for p in code}
    if "marketing" in kinds or "transactional" not in kinds:
        return "FAIL"
    if project.has(BULK_STORAGE, non_doc_files(project)):
        return "FAIL"
    return "WARN"


def applies(project):
    files = sender_files(project)
    return project.has(EMAIL_SENDER, files) or project.has(SMS_SENDER, files)


@dataclass(frozen=True)
class Sending:
    senders: list
    severity: str
    email: object
    sms: object


def _first_hit(project, pattern, files):
    return next(project.matches(pattern, files), None)


def _context(project):
    files = sender_files(project)
    senders = [p for p in files if _sends(project, p)]
    return Sending(
        senders, _severity(project, senders),
        _first_hit(project, EMAIL_SENDER, files),
        _first_hit(project, SMS_SENDER, files))


def check(project):
    ctx = _context(project)
    out = _consent(project, ctx.email or ctx.sms, ctx.senders, ctx.severity)
    if ctx.email:
        out += _email_rules(project, ctx.email, ctx.severity)
    if ctx.sms:
        out += _sms_rules(project, ctx.sms, ctx.severity)
    return out


def _note(severity):
    return TRANSACTIONAL_NOTE if severity == "WARN" else ""


def _consent(project, hit, senders, severity):
    path, m = hit
    if not project.has(CONSENT_STORED, non_doc_files(project), 0):
        return [project.found(
            Rule(DOMAIN, "MSG-NO-CONSENT-RECORD", severity), path, m.start(),
            "messages are sent but no consent record exists: store who, "
            "when, channel, source and wording per contact" + _note(severity))]
    return [
        project.found(
            Rule(DOMAIN, "MSG-SEND-UNCHECKED", "WARN"), p, 0,
            "sends messages without checking consent or the suppression "
            "list in this file")
        for p in senders
        if p.suffix.lower() in SOURCE_EXTS
        and _kind(project, p) != "transactional"
        and not project.has(CONSENT_CHECKED, [p])
    ]


def _email_rules(project, hit, severity):
    path, m = hit
    docs = non_doc_files(project)
    if not project.has(UNSUBSCRIBE, docs):
        return [project.found(
            Rule(DOMAIN, "MSG-NO-UNSUBSCRIBE", severity), path, m.start(),
            "emails are sent but no unsubscribe link exists" + _note(severity))]
    if not project.has(r"list-unsubscribe", docs):
        return [project.found(
            Rule(DOMAIN, "MSG-NO-LIST-UNSUBSCRIBE", "WARN"), path, m.start(),
            "add the List-Unsubscribe header (one-click); Gmail and Yahoo "
            "require it from bulk senders")]
    return []


def _sms_rules(project, hit, severity):
    path, m = hit
    docs = non_doc_files(project)
    out = []
    if not project.has(r"\bSTOP\b", docs, 0):
        out.append(project.found(
            Rule(DOMAIN, "MSG-SMS-NO-STOP", severity), path, m.start(),
            "SMS are sent but nothing tells the recipient to reply STOP"
            + _note(severity)))
    if not project.has(OPT_OUT_STORED, docs):
        out.append(project.found(
            Rule(DOMAIN, "MSG-SMS-NO-OPTOUT-STORE", severity), path, m.start(),
            "no opt-out storage: a STOP reply must be recorded and "
            "checked before every send" + _note(severity)))
    return out
