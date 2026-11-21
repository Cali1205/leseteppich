#!/bin/sh
# The repository and GitHub Actions logs are public.
# Strip signing identities (which contain the Apple account holder's real name) and emails.
exec sed -E \
  -e 's/((Apple|iPhone|iOS) (Development|Distribution|Developer)[^:"]*: )[^"(]*/\1***/g' \
  -e 's/[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/***@***/g'
