#!/usr/bin/env bash
# Drive agent-config-sync against a local origin and assert the published pi
# topology resolves every path a SKILL.md reaches outward for.
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

plugin="$tmp/origin/operator/pb-skills/plugins/pb"
mkdir -p "$plugin"/{instructions/work,standards,scripts}
echo 'Consult `../../standards/lookup.md`, then run `../../scripts/pb-executor`.' >"$plugin/instructions/work/SKILL.md"
echo 'lookup' >"$plugin/standards/lookup.md"
printf '#!/usr/bin/env bash\necho executor\n' >"$plugin/scripts/pb-executor"
chmod +x "$plugin/scripts/pb-executor"
echo '{"backends":{}}' >"$plugin/executor-backends.json"
# A second plugin offering only instructions must not break the first's copy.
mkdir -p "$tmp/origin/operator/pb-skills/plugins/bare/instructions/solo"
echo 'bare' >"$tmp/origin/operator/pb-skills/plugins/bare/instructions/solo/SKILL.md"

git -C "$tmp/origin/operator/pb-skills" init --quiet
git -C "$tmp/origin/operator/pb-skills" add -A
git -C "$tmp/origin/operator/pb-skills" -c user.email=t@t -c user.name=t commit --quiet -m init

home="$tmp/home"
mkdir -p "$home"
HOME="$home" AGENT_GIT_HOST="$tmp/origin" AGENT_CHECKOUT_DIR="$tmp/share" \
    AGENT_CONFIG_REPOS=operator/pb-skills "$repo/agent-config-sync"

published="$home/.pi/agent/skills/pb-skills"
skill_dir="$published/instructions/work"
[[ -f "$skill_dir/SKILL.md" ]] || {
    echo "pi topology: skill missing" >&2
    exit 1
}
# Every ../../ reference in the published skill must land on a real file.
while IFS= read -r relative; do
    [[ -e "$skill_dir/$relative" ]] || {
        echo "pi topology: cannot resolve $relative from $skill_dir" >&2
        exit 1
    }
done < <(grep -o '`\.\./\.\./[^`]*`' "$skill_dir/SKILL.md" | tr -d '`' | sort -u)
[[ -x "$published/scripts/pb-executor" ]] || {
    echo "pi topology: executor lost its executable bit" >&2
    exit 1
}
# pb-executor reads its catalog from the plugin root it infers, two levels up
# from its own path.
[[ -f "$published/executor-backends.json" ]] || {
    echo "pi topology: backend catalog missing from the plugin root" >&2
    exit 1
}
[[ -f "$published/instructions/solo/SKILL.md" ]] || {
    echo "pi topology: a sibling-less plugin was dropped" >&2
    exit 1
}

printf 'ok -- agent-config-sync publishes a pi topology whose outward paths resolve\n'
