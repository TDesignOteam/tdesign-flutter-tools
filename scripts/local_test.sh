#!/usr/bin/env bash
# 本地测试 API 文档生成工具
# 在 tdesign-component 目录下，通过 path 依赖指向 ../tdesign-flutter-tools
# 用法: TDESIGN_COMPONENT_ROOT=/path/to/tdesign-component ./scripts/local_test.sh [picker|popup|dialog|calendar|button]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
if [[ -n "${TDESIGN_COMPONENT_ROOT:-}" ]]; then
  COMPONENT_DIR="$(cd "${TDESIGN_COMPONENT_ROOT}" && pwd)"
elif [[ -d "${TOOLS_DIR}/../tdesign-flutter-v1/tdesign-component" ]]; then
  COMPONENT_DIR="$(cd "${TOOLS_DIR}/../tdesign-flutter-v1/tdesign-component" && pwd)"
else
  COMPONENT_DIR="$(cd "${TOOLS_DIR}/../tdesign-component" && pwd)"
fi
TARGET="${1:-picker}"

cd "${COMPONENT_DIR}"

echo "==> 工作目录: ${COMPONENT_DIR}"
echo "==> 本地 tools: ${TOOLS_DIR}"
echo "==> 生成组件: ${TARGET}"

run_generate() {
  local folder="$1"
  local names="$2"
  local folder_name="$3"

  # 使用已有 package_config，避免 dart run 触发 pub.dev 联网校验
  dart --packages="${COMPONENT_DIR}/.dart_tool/package_config.json" \
    run "${TOOLS_DIR}/bin/main.dart" generate \
    --folder "${folder}" \
    --name "${names}" \
    --folder-name "${folder_name}" \
    --output "example/assets/api/" \
    --only-api
}

case "${TARGET}" in
  picker)
    run_generate \
      "lib/src/components/picker" \
      "TPicker,TPickerOption,TPickerValue,TPickerColumns,TPickerLinked,TPickerKeys" \
      "picker"
    ;;
  popup)
    run_generate \
      "lib/src/components/popup" \
      "TPopup,TPopupOptions,TPopupHandle,TPopupPlacement,TPopupTrigger" \
      "popup"
    ;;
  button)
    run_generate \
      "lib/src/components/button" \
      "TButton,TButtonResolve,TButtonThemeData,TButtonSize,TButtonVariant,TButtonColorScheme,TButtonIconPosition,TButtonShape" \
      "button"
    ;;
  calendar)
    run_generate \
      "lib/src/components/calendar" \
      "TCalendar,TCalendarStyle,DateSelectType,TCalendarSubtitleContext,TCalendarCellModel" \
      "calendar"
    ;;
  dialog)
    run_generate \
      "lib/src/components/dialog" \
      "TConfirmDialog,TDialogButtonOptions,TDialogButtonStyle,TDialogScaffold,TDialogTitle,TDialogContent,TDialogInfoWidget,HorizontalNormalButtons,HorizontalTextButtons,TDialogButton" \
      "dialog"
    ;;
  *)
    echo "未知组件: ${TARGET}，可选: picker | popup | dialog | calendar | button"
    exit 1
    ;;
esac

echo "==> 完成，输出目录: ${COMPONENT_DIR}/example/assets/api/${TARGET}_api.md"
