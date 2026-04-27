#!/usr/bin/env bash
# ============================================================
# lib/animation-lib-check.sh — Animation library detection
# Sourced by: skills/init-project, skills/onboard, agents/plugin-advisor.
#
# Recommends `motion` (ex-`framer-motion`, rebranded Nov 2024) for
# React-family / Svelte stacks, and `motion-v` for Vue 3 / Nuxt.
#
# Override the project root with: ANIM_PROJECT_ROOT=/path before sourcing.
# ============================================================

ANIM_PROJECT_ROOT="${ANIM_PROJECT_ROOT:-$PWD}"

# Match a literal dep key in package.json (deps + devDeps + peerDeps).
# Args: $1 = exact dep name. Returns 0 if found, 1 otherwise. No output.
_anim_has_dep() {
  local pkg_json="$ANIM_PROJECT_ROOT/package.json"
  [ -f "$pkg_json" ] || return 1
  # The closing escaped quote anchors the match so "react" does not
  # collide with "react-native" or "react-dom".
  grep -Eq "\"$1\"[[:space:]]*:" "$pkg_json"
}

# Decide whether the project can consume the motion library.
# Outputs on stdout: '<status>|<package>|<reason>'
#   status  : eligible | no
#   package : motion | motion-v | -
#   reason  : short human-readable note
# Returns 0 if eligible, 1 if not.
detect_anim_eligibility() {
  local pkg_json="$ANIM_PROJECT_ROOT/package.json"

  if [ ! -f "$pkg_json" ]; then
    echo "no|-|no package.json (not a Node project)"
    return 1
  fi

  # React Native / Expo are excluded: motion targets the DOM, RN apps
  # should use react-native-reanimated instead.
  if _anim_has_dep "react-native" || _anim_has_dep "expo"; then
    echo "no|-|React Native stack — use react-native-reanimated"
    return 1
  fi

  if _anim_has_dep "react" || _anim_has_dep "next" \
     || _anim_has_dep "@remix-run/react" || _anim_has_dep "@astrojs/react"; then
    echo "eligible|motion|React-family stack"
    return 0
  fi

  if _anim_has_dep "vue" || _anim_has_dep "nuxt"; then
    echo "eligible|motion-v|Vue 3 / Nuxt stack"
    return 0
  fi

  if _anim_has_dep "svelte" || _anim_has_dep "@sveltejs/kit"; then
    echo "eligible|motion|Svelte stack"
    return 0
  fi

  if _anim_has_dep "astro"; then
    echo "no|-|Astro without a React/Vue/Svelte integration"
    return 1
  fi

  echo "no|-|no supported UI framework detected"
  return 1
}

# Look for any installed animation library.
# Outputs the detected package name on stdout (empty if none).
# Returns 0 if found, 1 otherwise.
is_anim_lib_installed() {
  local pkg_json="$ANIM_PROJECT_ROOT/package.json"
  [ -f "$pkg_json" ] || return 1

  local libs=(
    motion
    motion-v
    framer-motion
    gsap
    "@gsap/react"
    lottie-react
    react-spring
    "@react-spring/web"
    popmotion
    "@formkit/auto-animate"
  )

  local lib
  for lib in "${libs[@]}"; do
    if _anim_has_dep "$lib"; then
      echo "$lib"
      return 0
    fi
  done
  return 1
}

# Build the install command for the recommended package.
# Args: $1 = package name (motion | motion-v).
# Outputs the command on stdout. Returns 1 on missing arg.
recommend_anim_install_cmd() {
  local pkg="$1"
  [ -z "$pkg" ] && return 1
  local root="$ANIM_PROJECT_ROOT"

  if [ -f "$root/pnpm-lock.yaml" ]; then
    echo "pnpm add $pkg"
  elif [ -f "$root/yarn.lock" ]; then
    echo "yarn add $pkg"
  elif [ -f "$root/bun.lockb" ] || [ -f "$root/bun.lock" ]; then
    echo "bun add $pkg"
  else
    echo "npm install $pkg"
  fi
}
