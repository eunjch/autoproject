# 기획 PC 설정 (GPT / Codex CLI)

## 1. 설치
```powershell
winget install Git.Git OpenJS.NodeJS.LTS
npm i -g @openai/codex
codex login            # 브라우저에서 ChatGPT 구독 계정으로 로그인 (API 키 아님)
```

## 2. 저장소 받기
```powershell
git clone https://github.com/eunjch/autoproject.git C:\ai-studio
cd C:\ai-studio
git config user.name "planner-pc"
git config user.email "<본인 이메일>"
```
GitHub 인증은 **이 저장소 하나에만** Contents 쓰기 권한을 준 fine-grained 토큰을 쓴다 (처음 push할 때 Git Credential Manager가 저장).

## 3. 수동 1회 실행으로 확인
```powershell
powershell -ExecutionPolicy Bypass -File C:\ai-studio\planner\planner.ps1
```
GitHub에 `specs/0001-*.md`가 `status: ready`로 올라오면 성공. 로그는 `logs\planner-*.log`, Codex 출력은 `logs\planner-0001.out.txt`.

> 웹 검색 옵션 이름은 Codex 버전마다 다를 수 있다. 출력에 검색 흔적이 없으면 `codex exec --help`로 확인해서 `planner.ps1`의 `-c tools.web_search=true` 부분을 수정한다.

## 4. 작업 스케줄러 등록 (6시간마다)
```powershell
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\ai-studio\planner\planner.ps1'
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 6)
Register-ScheduledTask -TaskName 'AI-Planner' -Action $action -Trigger $trigger -Description 'Trend research -> spec -> git push'
```
중지: `Disable-ScheduledTask -TaskName AI-Planner`
