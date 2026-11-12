export function ContactForm({ go }: { go: () => void }) {
  return (
    <form>
      <label htmlFor="email">Email</label>
      <input id="email" type="email" />
      <label>
        Message
        <textarea name="msg" />
      </label>
      <input type="hidden" name="token" value="x" />
      <img src="/logo.png" alt="Company logo" />
      <img src="/divider.png" alt="" />
      <button
        type="submit"
        className="btn outline-none focus-visible:ring-2 focus-visible:ring-blue-500"
      >
        Send
      </button>
      <div role="button" tabIndex={0} onClick={go} onKeyDown={go}>
        Open
      </div>
      <div role="presentation" onClick={go}>
        <div role="dialog" aria-modal="true" onClick={(e) => e.stopPropagation()}>
          Dialog
        </div>
      </div>
      <input type="file" className="hidden" />
      <div className="backdrop" onClick={go} />
    </form>
  );
}
