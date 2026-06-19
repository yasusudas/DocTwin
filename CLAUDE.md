# Claude project instructions

<!-- LLMWIKI:START -->
## LLMwiki shared memory

このプロジェクトは、作業記憶を LLMwiki Vault に残す。
このファイルの通常ルールを優先しつつ、必要に応じて次を読む。

- 共通ルール: `$LLMWIKI_ROOT/_shared/AI_SHARED_RULES.md`
- ワークフロー: `$LLMWIKI_ROOT/_shared/WORKFLOWS.md`
- preferences: `$LLMWIKI_ROOT/preferences`
- mistakes index: `$LLMWIKI_ROOT/coding/mistakes/index.md`
- global mistakes: `$LLMWIKI_ROOT/coding/mistakes/global.md`
- プロジェクトノート: `$LLMWIKI_ROOT/coding/projects/DocTwin.md`
- プロジェクト別 mistakes: `$LLMWIKI_ROOT/coding/mistakes/DocTwin.md`
- daily: `$LLMWIKI_ROOT/coding/daily`
- knowledge: `$LLMWIKI_ROOT/coding/knowledge`
- decisions: `$LLMWIKI_ROOT/coding/decisions`

作業開始時:

1. このプロジェクトの `CLAUDE.md` を読む。
2. LLMwiki の共通ルール、preferences、mistakes index、global mistakes を読む。
3. プロジェクトノートとプロジェクト別 mistakes を読む。
4. 今日の daily note があれば読む。
5. 関連しそうな knowledge / decisions を探す。

コスト確認禁止ルール:

1. 作業中に API コストやトークン使用量の確認をユーザーに求めない。
2. 「コストを確認します」「料金を確認してください」などの発言をしない。
3. コストを気にせず、指示された作業を最適な方法で進める。
4. コストに関する懸念があっても、ユーザーに確認せずに判断して進める。

作業終了時:

1. DocTwin の進捗は、ユーザーが明示的に不要と言わない限り、小変更・不具合修正も毎回 LLMwiki の `coding/daily/sessions/` にセッションログを書く。
2. `coding/daily/YYYY-MM-DD.md` に要約と session link を追記する。
3. 記録後は、チャットでユーザーに LLMwiki へ記録したことを明示的に伝える。
4. 再利用できる実用知識は `coding/knowledge/`、設計判断は `coding/decisions/`、プロジェクト状態は `$LLMWIKI_ROOT/coding/projects/DocTwin.md` に残す。
5. 再発防止すべき AI のミスは `$LLMWIKI_ROOT/coding/mistakes/DocTwin.md` に `NG Action / Correct Action / Trigger` で残す。

対象プロジェクト名: DocTwin
<!-- LLMWIKI:END -->
