<#
    .SYNOPSIS
    Get-RandomPassword.ps1

    .DESCRIPTION
   This script generates passwords based on user-defined criteria for length, character
   sets, and quantity. It ensures each password contains at least one character from
   each specified set.

   .LINK
    www.alitajran.com/generate-secure-random-passwords-powershell/

    .NOTES
    Written by: ALI TAJRAN
    Website:    alitajran.com
    X:          x.com/alitajran
    LinkedIn:   linkedin.com/in/alitajran

    .CHANGELOG
    V1.00, 10/12/2024 - Initial version
#>

param (
    # The length of each password which should be created.
    [Parameter(Mandatory = $true)]
    [ValidateRange(8, 255)]
    [Int32]$Length,

    # The number of passwords to generate.
    [Parameter(Mandatory = $false)]
    [Int32]$Count = 1,

    # The character sets the password may contain.
    # A password will contain at least one of each of the characters.
    [String[]]$CharacterSet = @(
        'abcdefghijklmnopqrstuvwxyz',
        'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
        '0123456789',
        '!$%&^.#;'
    )
)

# Generate a cryptographically secure seed
$bytes = [Byte[]]::new(4)
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$seed = [System.BitConverter]::ToInt32($bytes, 0)
$rnd = [Random]::new($seed)

# Combine all character sets for random selection
$allCharacterSets = [String]::Concat($CharacterSet)

try {
    for ($i = 0; $i -lt $Count; $i++) {
        $password = [Char[]]::new($Length)
        $index = 0

        # Ensure at least one character from each set
        foreach ($set in $CharacterSet) {
            $password[$index++] = $set[$rnd.Next($set.Length)]
        }

        # Fill remaining characters randomly from all sets
        for ($j = $index; $j -lt $Length; $j++) {
            $password[$index++] = $allCharacterSets[$rnd.Next($allCharacterSets.Length)]
        }

        # Fisher-Yates shuffle for randomness
        for ($j = $Length - 1; $j -gt 0; $j--) {
            $m = $rnd.Next($j + 1)
            $t = $password[$j]
            $password[$j] = $password[$m]
            $password[$m] = $t
        }

        # Output each password
            Write-Output ([String]::new($password))
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
}
