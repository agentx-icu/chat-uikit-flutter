import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_common/data/message/tencent_cloud_chat_draft_data_provider.dart';

void main() {
  test('drafts are normalized and isolated by full account ID', () async {
    final store = _MemoryDraftStore();
    final provider = TencentCloudChatDraftDataProvider(store: store);

    await provider.saveDraft(
      conversationID: ' c2c_Friend ',
      accountToxId: ' account-a ',
      draft: 'account A draft',
    );
    await provider.saveDraft(
      conversationID: 'c2c_friend',
      accountToxId: 'ACCOUNT-B',
      draft: 'account B draft',
    );

    expect(
      await provider.loadDraft(
        conversationID: 'c2c_Friend',
        accountToxId: 'ACCOUNT-A',
      ),
      'account A draft',
    );
    expect(
      await provider.loadDraft(
        conversationID: 'c2c_friend',
        accountToxId: 'account-b',
      ),
      'account B draft',
    );
    expect(store.values, hasLength(2));
  });

  test('conversation keys preserve group ID case', () async {
    final store = _MemoryDraftStore();
    final provider = TencentCloudChatDraftDataProvider(store: store);

    await provider.saveDraft(
      conversationID: 'group_Team',
      accountToxId: 'account',
      draft: 'upper draft',
    );
    await provider.saveDraft(
      conversationID: 'group_team',
      accountToxId: 'ACCOUNT',
      draft: 'lower draft',
    );

    expect(
      await provider.loadDraft(
        conversationID: 'group_Team',
        accountToxId: 'account',
      ),
      'upper draft',
    );
    expect(
      await provider.loadDraft(
        conversationID: 'group_team',
        accountToxId: 'account',
      ),
      'lower draft',
    );
    expect(store.values, hasLength(2));
  });

  test('writes complete in invocation order and empty drafts remove', () async {
    final firstWrite = Completer<void>();
    final store = _MemoryDraftStore(firstWrite: firstWrite);
    final provider = TencentCloudChatDraftDataProvider(store: store);

    final first = provider.saveDraft(
      conversationID: 'c2c_friend',
      accountToxId: 'account',
      draft: 'first',
    );
    final second = provider.saveDraft(
      conversationID: 'c2c_friend',
      accountToxId: 'account',
      draft: 'second',
    );
    await Future<void>.delayed(Duration.zero);

    expect(store.writeValues, ['first']);
    firstWrite.complete();
    await Future.wait([first, second]);
    expect(store.writeValues, ['first', 'second']);

    await provider.saveDraft(
      conversationID: 'c2c_friend',
      accountToxId: 'account',
      draft: '',
    );
    expect(
      await provider.loadDraft(
        conversationID: 'c2c_friend',
        accountToxId: 'account',
      ),
      isNull,
    );
  });

  test('legacy conversation draft migrates only to the requesting account',
      () async {
    final store = _MemoryDraftStore()
      ..values['tencent_cloud_chat_draft:c2c_friend'] = 'legacy draft';
    final provider = TencentCloudChatDraftDataProvider(store: store);

    final results = await Future.wait([
      provider.loadDraft(
        conversationID: 'c2c_friend',
        accountToxId: 'account-a',
      ),
      provider.loadDraft(
        conversationID: 'c2c_friend',
        accountToxId: 'account-b',
      ),
    ]);

    expect(results, ['legacy draft', isNull]);
    expect(
      await provider.loadDraft(
        conversationID: 'c2c_friend',
        accountToxId: 'account-a',
      ),
      'legacy draft',
    );
    expect(store.values, {
      'tencent_cloud_chat_draft:ACCOUNT-A:c2c_friend': 'legacy draft',
    });
  });
}

class _MemoryDraftStore implements TencentCloudChatDraftStore {
  _MemoryDraftStore({this.firstWrite});

  final Completer<void>? firstWrite;
  final Map<String, String> values = {};
  final List<String> writeValues = [];

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> write(String key, String value) async {
    writeValues.add(value);
    if (writeValues.length == 1 && firstWrite != null) {
      await firstWrite!.future;
    }
    values[key] = value;
  }
}
