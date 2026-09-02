BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
}

Describe "Bootstrap source trust" {
    BeforeAll {
        $script:startScript = Get-Content -Path (Join-Path $script:repoRoot "scripts\start.ps1") -Raw
    }

    It "rejects remote or in-memory startup before checking privileges" {
        $guardIndex = $script:startScript.IndexOf('if (-not $PSCommandPath)')
        $privilegeCheckIndex = $script:startScript.IndexOf('WindowsBuiltInRole]::Administrator')

        $guardIndex | Should -BeGreaterThan -1
        $privilegeCheckIndex | Should -BeGreaterThan $guardIndex
        $script:startScript | Should -Match 'Remote or in-memory execution is blocked\.'
    }

    It "does not download or dynamically compile code during elevation" {
        $script:startScript | Should -Not -Match '(?i)\birm\b|Invoke-RestMethod|ScriptBlock::Create'
    }

    It "relaunches only the current local script" {
        $script:startScript | Should -Match '\$script = "& \{ & `''\$\(\$PSCommandPath\)`'''
    }
}

Describe "PowerShell profile source trust" {
    BeforeAll {
        $script:profileInstallerPath = Join-Path $script:repoRoot "functions\private\Invoke-WinUtilInstallPSProfile.ps1"
        $script:profileInstaller = Get-Content -Path $script:profileInstallerPath -Raw
        $script:features = Get-Content -Path (Join-Path $script:repoRoot "config\feature.json") -Raw | ConvertFrom-Json
    }

    It "does not download, dynamically compile, or execute remote profile code" {
        $script:profileInstaller | Should -Not -Match '(?i)\birm\b|Invoke-RestMethod|Invoke-WebRequest|ScriptBlock::Create|\biex\b'
    }

    It "does not install dependencies or start a child process" {
        $script:profileInstaller | Should -Not -Match '(?i)\bwinget\b|Install-WinUtilWinget|Start-Process|\bwt\b|\bpwsh\b'
    }

    It "reports that the optional installer is blocked without changing the system" {
        $script:profileInstaller | Should -Match 'blocks the CTT PowerShell Profile installer'
        $script:profileInstaller | Should -Match 'No changes were made\.'
        $script:features.WPFWinUtilInstallPSProfile.Content | Should -Be 'CTT PowerShell Profile - Blocked'
    }
}

Describe "Configuration export source trust" {
    BeforeAll {
        $script:impexPath = Join-Path $script:repoRoot "functions\public\Invoke-WPFImpex.ps1"
        $script:impex = Get-Content -Path $script:impexPath -Raw
    }

    It "does not copy a remote execution command" {
        $script:impex | Should -Not -Match '(?i)\birm\b|\biex\b|christitus\.com/win'
    }

    It "builds the command from the trusted local script and resolved config paths" {
        $script:impex | Should -Match '\$PSCommandPath'
        $script:impex | Should -Match 'Resolve-Path -LiteralPath \$Config'
        $script:impex | Should -Match 'Set-Clipboard -Value \$localCommand'
    }
}
