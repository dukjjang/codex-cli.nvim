"""Deterministic app-server fixture; never calls a model or touches project files."""
import json, sys, time

def emit(value):
    raw = json.dumps(value, ensure_ascii=False) + '\n'
    # Deliberately split JSON and Korean text across stdout callbacks.
    for part in (raw[:17], raw[17:]):
        sys.stdout.write(part)
        sys.stdout.flush()
        time.sleep(.001)

for raw in sys.stdin:
    msg = json.loads(raw)
    method, params = msg.get('method'), msg.get('params', {})
    if method == 'initialize':
        emit({'id': msg['id'], 'result': {}})
    elif method in ('thread/start', 'thread/resume'):
        assert params['sandbox'] == 'read-only'
        emit({'id': msg['id'], 'result': {'thread': {'id': 'test-thread'}}})
    elif method == 'turn/start':
        text = params['input'][0]['text']
        is_apply = 'Mode: 적용.' in text
        assert params['sandboxPolicy']['type'] == ('workspaceWrite' if is_apply else 'readOnly')
        emit({'id': msg['id'], 'result': {'turn': {'id': 'test-turn'}}})
        emit({'method': 'turn/started', 'params': {'threadId': 'test-thread', 'turn': {'id': 'test-turn'}}})
        if 'HOLD' in text:
            continue
        for delta in ['안녕', '하세요.\n', '```lua\nprint("hello")\n```']:
            emit({'method': 'item/agentMessage/delta', 'params': {'threadId': 'test-thread', 'itemId': str(msg['id']), 'delta': delta}})
            if 'STREAM' in text:
                time.sleep(.2)
        emit({'method': 'turn/diff/updated', 'params': {'threadId': 'test-thread', 'diff': '--- a/test.lua\n+++ b/test.lua\n@@ -1 +1 @@\n-old\n+new'}})
        emit({'method': 'turn/completed', 'params': {'threadId': 'test-thread', 'turn': {'id': 'test-turn', 'status': 'completed'}}})
    elif method == 'turn/interrupt':
        emit({'id': msg['id'], 'result': {}})
        emit({'method': 'turn/completed', 'params': {'threadId': 'test-thread', 'turn': {'id': 'test-turn', 'status': 'interrupted'}}})
