"""Deterministic app-server fixture; never calls a model or touches project files."""
import json, os, sys, time

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
    elif method == 'skills/list':
        emit({'id': msg['id'], 'result': {'data': [{
            'cwd': params['cwds'][0], 'errors': [],
            'skills': [
                {'name': name, 'description': '긴 설명을 가진 스킬입니다. ' * 12 + name, 'path': '/test/' + name + '/SKILL.md', 'scope': 'user', 'enabled': enabled}
                for name, enabled in [('commit', True), ('commit-all', True), ('plugin:review', True), ('disabled', False)]
            ]}]}})
    elif method == 'model/list':
        second = params.get('cursor') == 'second'
        model = 'test-beta' if second else 'test-alpha'
        emit({'id': msg['id'], 'result': {'data': [{
            'id': model, 'model': model, 'displayName': model, 'hidden': False,
            'isDefault': not second, 'defaultReasoningEffort': 'low',
            'supportedReasoningEfforts': [
                {'reasoningEffort': 'low', 'description': 'Quick answers'},
                {'reasoningEffort': 'high', 'description': 'Deeper reasoning'},
            ],
        }], 'nextCursor': None if second else 'second'}})
    elif method in ('thread/start', 'thread/resume'):
        assert params['sandbox'] == 'read-only'
        emit({'id': msg['id'], 'result': {'thread': {'id': 'test-thread'}, 'model': 'test-alpha', 'reasoningEffort': 'low'}})
    elif method == 'turn/start':
        text = params['input'][0]['text']
        is_apply = 'Mode: 적용.' in text
        assert params['sandboxPolicy']['type'] == ('workspaceWrite' if is_apply else 'readOnly')
        emit({'id': msg['id'], 'result': {'turn': {'id': 'test-turn'}}})
        emit({'method': 'turn/started', 'params': {'threadId': 'test-thread', 'turn': {'id': 'test-turn'}}})
        if 'HOLD' in text:
            continue
        response = [params.get('model', 'default') + ' / ' + str(params.get('effort', 'default'))] if 'MODEL_CHECK' in text else ['안녕', '하세요.\n', '```lua\nprint("hello")\n```']
        if 'INSTRUCTIONS_CHECK' in text:
            response = [text.split('External instructions for this request', 1)[1].split('End of external instructions.', 1)[0]]
        if 'SKILL_CHECK' in text:
            skills = [item for item in params['input'] if item['type'] == 'skill']
            for skill in skills:
                assert skill['path'] == '/test/' + skill['name'] + '/SKILL.md'
            response = ['skills=' + ','.join(skill['name'] for skill in skills)]
        for delta in response:
            emit({'method': 'item/agentMessage/delta', 'params': {'threadId': 'test-thread', 'itemId': str(os.getpid()) + ':' + str(msg['id']), 'delta': delta}})
            if 'STREAM' in text:
                time.sleep(.2)
        emit({'method': 'turn/diff/updated', 'params': {'threadId': 'test-thread', 'diff': '--- a/test.lua\n+++ b/test.lua\n@@ -1 +1 @@\n-old\n+new'}})
        emit({'method': 'turn/completed', 'params': {'threadId': 'test-thread', 'turn': {'id': 'test-turn', 'status': 'completed'}}})
    elif method == 'turn/interrupt':
        emit({'id': msg['id'], 'result': {}})
        emit({'method': 'turn/completed', 'params': {'threadId': 'test-thread', 'turn': {'id': 'test-turn', 'status': 'interrupted'}}})
