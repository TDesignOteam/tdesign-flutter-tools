#!/usr/bin/env bash
# 本地测试 API 文档生成工具
# 在 tdesign-component 目录下，通过 path 依赖指向 ../tdesign-flutter-tools
# 用法: ./scripts/local_test.sh [picker|calendar|dialog]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPONENT_DIR="$(cd "${TOOLS_DIR}/../tdesign-component" && pwd)"
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
      "TPicker,TPickerOption,TPickerValue,TPickerLoadEvent,TPickerColumns,TPickerLinked,TPickerItems,TPickerKeys" \
      "picker"
    ;;
  calendar)
    run_generate \
      "lib/src/components/calendar" \
      "TCalendar,TCalendarPopup,TCalendarStyle,TCalendarDataSource,TLunarInfo,TCalendarDateType" \
      "calendar"
    ;;
  dialog)
    run_generate \
      "lib/src/components/dialog" \
      "TAlertDialog,TConfirmDialog,TDialogButtonOptions,TDialogScaffold,TDialogTitle,TDialogContent,TDialogInfoWidget,HorizontalNormalButtons,HorizontalTextButtons,TDialogButton,TImageDialog,TInputDialog" \
      "dialog"
    ;;
  *)
    echo "未知组件: ${TARGET}，可选: picker | calendar | dialog"
    exit 1
    ;;
esac

echo "==> 完成，输出目录: ${COMPONENT_DIR}/example/assets/api/${TARGET}_api.md"
