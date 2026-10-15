# AI Studio — 기획 PC / 개발 PC 자동 파이프라인

```
[기획 PC: Codex CLI]                      [개발 PC: Claude Code + Docker]
 트렌드 조사 → specs/NNNN-*.md  ──git──▶   ready 기획서 선점 → apps/ 구현
 (6시간마다, ready 2개 이상이면 쉼)          → docker compose 검증 → reports/ → main merge
                                 ◀──git──  status: in-progress / done / failed
```

두 PC 모두 API 키가 아니라 **구독 계정 로그인**으로 동작한다.

## 폴더
| 경로 | 내용 |
|---|---|
| `specs/` | 기획서. `status: ready → in-progress → done / failed` |
| `apps/<id-slug>/` | 기획서별 결과물 (Dockerfile + docker-compose.yml) |
| `reports/<id>.md` | 개발 결과 보고 |
| `planner/` | 기획 PC 스크립트와 프롬프트 |
| `builder/` | 개발 PC 스크립트와 프롬프트 |
| `scripts/common.ps1` | 공용 함수 (로그, 잠금, 시간 제한, 상태 변경) |
| `logs/` | 실행 로그 (git 제외) |

## 시작하기
1. 이 폴더를 GitHub private 저장소로 올린다.
2. [docs/setup-planning-pc.md](docs/setup-planning-pc.md)
3. [docs/setup-dev-pc.md](docs/setup-dev-pc.md)

> ⚠️ 스크립트는 실행할 때마다 작업 폴더를 `origin/main` 상태로 초기화한다 (`reset --hard`, `clean -fd`). **각 PC에는 파이프라인 전용 clone(예: `C:\ai-studio`)을 두고**, 직접 수정하는 폴더(예: 이 `d:\newp`)에서는 스크립트를 실행하지 않는다.

## 안전장치
- 실행 시간 제한: 기획 30분, 개발 60분 (넘으면 프로세스 강제 종료 → `failed`)
- 하루 실행 횟수 제한: 기획 4회, 개발 12회 (스크립트 파라미터로 조정)
- Claude 권한 허용목록: `builder/claude-settings.json` (push/reset/rm -rf 등 차단). 자동 실행에만 `--settings`로 적용되고, 평소 대화형 작업에는 걸리지 않음
- 실패한 작업은 `feat/<id>` 브랜치에 남아 나중에 확인 가능
- 실행 도중 PC가 꺼지는 등 비정상 종료되면 다음 실행 때 남은 변경을 정리하고, `in-progress`로 남은 기획서는 `failed`로 바꿈

## 다시 시도
`failed`가 된 기획서는 `status: ready`로 바꿔 push하면 다음 개발 실행 때 다시 시도한다.
