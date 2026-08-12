#!/bin/bash
#
# Cai hook vao .git/hooks.
#
# Git khong theo doi .git/hooks, nen hook khong tu di theo khi clone.
# Chay script nay mot lan sau khi clone repo ve may moi.
#
set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/hooks"
dst_dir="$repo_root/.git/hooks"

for hook in "$src_dir"/*; do
  name=$(basename "$hook")
  install -m 755 "$hook" "$dst_dir/$name"
  echo "Da cai: $dst_dir/$name"
done

echo
echo "Kiem tra nhanh: tao mot file chua ID access key gia (bon chu AKIA roi"
echo "16 ky tu hoa hoac so), git add -f no, rooi commit. Hook PHAI tu choi."
echo
echo "Luu y: chinh script nay khong duoc chua chuoi khop mau do, neu khong"
echo "hook se chan moi commit dong toi no."
