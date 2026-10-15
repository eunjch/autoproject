# 개발 에이전트 규칙 (개발 PC / Claude Code)

이 저장소는 기획 PC(GPT)가 `specs/`에 기획서를 올리고, 개발 PC(Claude)가 `builder/builder.ps1`로 자동 구현하는 파이프라인이다.

## 반드시 지킬 것
- 코드는 지정된 `apps/<id-slug>/` 폴더 안에만 작성한다. `specs/`, `planner/`, `builder/`, `scripts/`, `.claude/`는 수정하지 않는다.
- 모든 앱은 Docker로 실행한다. 호스트에 런타임이나 패키지를 설치하지 않는다.
- 포트는 다른 앱과 겹치지 않게 `8000 + 기획서 id 숫자`를 쓴다 (예: 0003 → 8003).
- git은 현재 브랜치에서 commit만 한다. push, merge, checkout, reset, rebase는 스크립트가 처리한다.
- 비밀값을 하드코딩하지 않는다. 필요하면 `.env.example`을 만든다.
- 완료 기준을 실제로 확인하지 않았다면 보고서에 `result: success`를 쓰지 않는다.
