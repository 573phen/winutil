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
