# 개발 PC 설정 (Claude Code + Docker)

## 1. 설치
```powershell
winget install Git.Git Docker.DockerDesktop
irm https://claude.ai/install.ps1 | iex     # Claude Code
claude                                       # 처음 한 번 실행해서 Claude 구독 계정으로 로그인한 뒤 종료
```
Docker Desktop은 WSL2 백엔드로 실행하고, "Start Docker Desktop when you sign in"을 켠다.

## 2. 저장소 받기
```powershell
git clone https://github.com/eunjch/autoproject.git C:\ai-studio
cd C:\ai-studio
git config user.name "dev-pc"
git config user.email "<본인 이메일>"
```
GitHub 토큰은 기획 PC와 같은 방식으로 이 저장소 하나에만 권한을 준다. 가능하면 개발 PC 작업은 전용 Windows 계정에서 돌린다.

## 3. 수동 1회 실행으로 확인
기획 PC가 `ready` 기획서를 하나 올린 뒤 실행한다:
```powershell
powershell -ExecutionPolicy Bypass -File C:\ai-studio\builder\builder.ps1
```
확인할 것:
- 기획서가 `in-progress`를 거쳐 `done` 또는 `failed`로 바뀐다
- `apps/<id-slug>/`, `reports/<id>.md`가 main에 들어온다 (실패하면 `feat/<id>` 브랜치에 남음)
- Claude 출력은 `logs\builder-<id>.out.txt`

권한 때문에 막히는 명령이 있으면 `builder/claude-settings.json`의 `allow`에 추가한다.

## 4. 작업 스케줄러 등록 (30분마다)
```powershell
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\ai-studio\builder\builder.ps1'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 30)
Register-ScheduledTask -TaskName 'AI-Builder' -Action $action -Trigger $trigger -Description 'spec -> Claude Code build -> git'
```
Docker를 써야 하므로 **로그인한 사용자 세션에서 실행**하는 기본값을 유지한다. 실행이 겹치면 잠금 파일 때문에 두 번째 실행은 바로 종료된다.
