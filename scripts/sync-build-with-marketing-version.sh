#!/usr/bin/env bash
set -eo pipefail

ROOT="${SRCROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
STATE_FILE="${ROOT}/Supporting/VersionBuildState.json"
GENERATED_XCCONFIG="${ROOT}/Supporting/GeneratedVersion.xcconfig"
PBXPROJ="${ROOT}/ERP Mobile.xcodeproj/project.pbxproj"

mkdir -p "${ROOT}/Supporting"

read_state_value() {
  local key="$1"
  local default="$2"
  if [[ ! -f "${STATE_FILE}" ]]; then
    printf '%s' "${default}"
    return
  fi

  local value=""
  case "${key}" in
    marketingVersion)
      value="$(sed -n 's/.*"marketingVersion"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "${STATE_FILE}" | head -n 1)"
      ;;
    buildNumber)
      value="$(sed -n 's/.*"buildNumber"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p' "${STATE_FILE}" | head -n 1)"
      ;;
  esac

  if [[ -n "${value}" ]]; then
    printf '%s' "${value}"
  else
    printf '%s' "${default}"
  fi
}

write_state() {
  local marketing="$1"
  local build="$2"
  cat > "${STATE_FILE}" <<EOF
{
  "marketingVersion": "${marketing}",
  "buildNumber": ${build}
}
EOF
}

write_generated_xcconfig() {
  local build="$1"
  printf 'CURRENT_PROJECT_VERSION = %s\n' "${build}" > "${GENERATED_XCCONFIG}"
}

if [[ -n "${MARKETING_VERSION:-}" ]]; then
  CURRENT_MARKETING="${MARKETING_VERSION}"
else
  CURRENT_MARKETING="$(grep -m1 'MARKETING_VERSION = ' "${PBXPROJ}" | sed -E 's/.*MARKETING_VERSION = ([^;]+);/\1/' | tr -d '[:space:]')"
fi

if [[ -z "${CURRENT_MARKETING}" ]]; then
  echo "warning: Could not determine MARKETING_VERSION from project settings." >&2
  exit 0
fi

LAST_MARKETING="$(read_state_value marketingVersion "")"
BUILD="$(read_state_value buildNumber "0")"
BUILD="${BUILD:-0}"

if [[ "${CURRENT_MARKETING}" != "${LAST_MARKETING}" ]]; then
  BUILD=$((BUILD + 1))
  write_state "${CURRENT_MARKETING}" "${BUILD}"
  write_generated_xcconfig "${BUILD}"
  echo "Marketing version ${CURRENT_MARKETING}: build incremented to ${BUILD}"
elif [[ ! -f "${GENERATED_XCCONFIG}" ]]; then
  write_generated_xcconfig "${BUILD}"
fi
