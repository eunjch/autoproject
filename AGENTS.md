# 기획 에이전트 규칙 (기획 PC / Codex CLI)

- 할 일은 `specs/` 아래에 새 기획서 파일 하나를 쓰는 것뿐이다. 형식은 `specs/_template.md`를 따른다.
- 다른 파일은 수정하지 않고 git 명령도 실행하지 않는다. 커밋과 push는 `planner/planner.ps1`이 처리한다.
- 기획은 개발 PC가 1시간 안에 Docker로 만들 수 있는 크기로 제한하고, 유료 API 키나 결제가 필요한 기능은 넣지 않는다.
