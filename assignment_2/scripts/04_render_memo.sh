#!/bin/sh
# Render the memo: Markdown -> Typst (Quarto) -> PDF, with outputs/ as the Typst root
# so the memo can reference ../figures/. Run from assignment_2/.
set -e
cd outputs/memo
quarto render governance_land_use_memo.md --to typst >/dev/null 2>&1 || true
quarto typst compile --root .. governance_land_use_memo.typ governance_land_use_memo.pdf
