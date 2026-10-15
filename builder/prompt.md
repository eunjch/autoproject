기획서 `{{SPEC_PATH}}`를 읽고 그대로 구현해라. 사람은 개입하지 않으니 질문하지 말고 끝까지 진행한다.

## 작업 순서
1. 기획서와 `CLAUDE.md` 규칙을 읽는다.
2. `{{APP_DIR}}/` 아래에만 코드를 작성한다. `Dockerfile`과 `docker-compose.yml`을 반드시 포함한다.
3. `docker compose up --build -d`로 띄우고, 기획서의 `## 완료 기준`을 하나씩 실제로 확인한다 (curl, 테스트 코드 등).
4. 실패하면 고쳐서 다시 확인한다. 의미 있는 단위마다 git commit 한다 (현재 브랜치에서만, push·merge·브랜치 전환 금지).
5. 마지막에 `{{REPORT_PATH}}`를 아래 형식으로 작성하고 commit 한다.

## 보고서 형식
```
---
result: success   # 완료 기준을 모두 통과했을 때만 success, 아니면 failure
---
# 결과 보고
## 실행 방법
## 완료 기준 확인 결과 (항목별 통과/실패와 확인 방법)
## 남은 이슈
```
