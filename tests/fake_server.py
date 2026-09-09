"""Deterministic app-server fixture; never calls a model or touches project files."""
import json, os, sys, time

pending_approvals = {}

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
    if method is None and msg.get('id') in pending_approvals:
        command = pending_approvals.pop(msg['id'])
        decision = msg['result']['decision']
        assert decision in ('accept', 'decline'), 'approval must not persist for a session'
        emit({'method': 'item/agentMessage/delta', 'params': {'threadId': 'test-thread', 'itemId': str(msg['id']), 'delta': command + ': ' + ('executed' if decision == 'accept' else 'blocked')}})
        emit({'method': 'turn/completed', 'params': {'threadId': 'test-thread', 'turn': {'id': 'test-turn', 'status': 'completed'}}})
    elif method == 'initialize':
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
        assert params['approvalsReviewer'] == 'user'
        emit({'id': msg['id'], 'result': {'thread': {'id': 'test-thread'}, 'model': 'test-alpha', 'reasoningEffort': 'low'}})
    elif method == 'turn/start':
        assert params['approvalsReviewer'] == 'user'
        text = params['input'][0]['text']
        is_apply = 'Mode: 적용.' in text
        assert params['sandboxPolicy']['type'] == ('workspaceWrite' if is_apply else 'readOnly')
        extra_root = os.environ.get('CODEX_TEST_WRITABLE_ROOT')
        if extra_root:
            if is_apply:
                assert params['sandboxPolicy']['writableRoots'] == [params['cwd'], extra_root]
                assert params['sandboxPolicy']['networkAccess'] is False
            else:
                assert 'writableRoots' not in params['sandboxPolicy']
        emit({'id': msg['id'], 'result': {'turn': {'id': 'test-turn'}}})
        emit({'method': 'turn/started', 'params': {'threadId': 'test-thread', 'turn': {'id': 'test-turn'}}})
        if 'APPROVAL_CHECK' in text:
            command = 'git push origin main' if 'PUSH_CHECK' in text else 'git commit -m test'
            reason = None
            if 'PUBLISH_CHECK' in text:
                assert 'request execution approval ONCE' in text
                assert 'Do not stage or request Git index write permission separately' in text
                assert 'Git index and metadata writes' in text
                assert 'sandbox escalation for this complete command on its first attempt' in text
                command = 'git add -- src/change.lua && git commit -m "feat: publish reviewed change" && git push origin HEAD:main'
                reason = '대상 파일: src/change.lua\n필요 권한: Git 인덱스 쓰기 및 푸시 네트워크 접근\n커밋 메시지: feat: publish reviewed change\n푸시 대상: origin / main\n커밋·푸시를 진행할까요?'
            request_id = 'approval-' + str(msg['id'])
            pending_approvals[request_id] = command
            emit({'id': request_id, 'method': 'item/commandExecution/requestApproval', 'params': {'threadId': 'test-thread', 'turnId': 'test-turn', 'itemId': request_id, 'command': command, 'reason': reason, 'cwd': params['cwd']}})
            continue
        if 'ACTIVITY_CHECK' in text:
            kind = text.split('ACTIVITY_CHECK ', 1)[1].split()[0]
            emit({'method': 'item/agentMessage/delta', 'params': {'threadId': 'test-thread', 'itemId': 'activity-' + str(msg['id']), 'delta': '작업을 이어갑니다.'}})
            emit({'method': 'item/started', 'params': {'threadId': 'test-thread', 'item': {'id': 'activity', 'type': kind}}})
            continue
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
