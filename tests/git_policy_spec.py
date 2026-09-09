"""Check the bundled policy with the real Codex rule engine, without executing Git."""
import json
from pathlib import Path
import subprocess
import tempfile

rules = Path(__file__).resolve().parents[1] / 'rules/git-approval.rules'
with tempfile.TemporaryDirectory(prefix='codex-git-policy-') as directory:
    allow = Path(directory) / 'existing.rules'
    allow.write_text('prefix_rule(pattern=["git"], decision="allow")\n')
    for command, expected in [
        (['git', 'commit', '-m', 'test'], 'prompt'),
        (['git', 'push', 'origin', 'main'], 'prompt'),
        (['git', '-C', '/tmp/repo', 'push'], 'prompt'),
        (['git', '-c', 'alias.publish=push', 'publish'], 'prompt'),
        (['/usr/bin/git', 'commit', '-m', 'test'], 'prompt'),
        (['git', 'status'], 'allow'),
        (['git', 'diff'], 'allow'),
        (['git', 'log'], 'allow'),
    ]:
        result = json.loads(subprocess.check_output([
            'codex', 'execpolicy', 'check', '--rules', str(allow),
            '--rules', str(rules), '--', *command,
        ]))
        assert result.get('decision') == expected, (command, result)
print('PASS: commit/push require approval despite allow rules; Git options prompt; status/diff/log stay allowed')
