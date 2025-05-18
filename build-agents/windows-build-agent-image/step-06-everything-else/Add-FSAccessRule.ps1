<#
	.SYNOPSIS
	Add-FSAccessRule.ps1
	
	.DESCRIPTION
	This script adds an access rule to the ACL of a filesystem directory or file.
	
	.NOTES
	Written by Daniel Collins, released to public domain.
#>

param (
	# The path to the directory/file to add the access rule to.
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[String]$Path,
	
	# The identity (user, group, etc) to allow or deny access to.
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[String]$Identity,
	
	# Access rights to allow or deny (see System.Security.AccessControl.FileSystemRights)
	[Parameter(Mandatory = $true)]
	[ValidateNotNullOrEmpty()]
	[String]$Rights,
	
	[Parameter(Mandatory = $false)]
	[ValidateSet(
		'This folder only',
		'This folder, sub-folders and files',
		'This folder and sub-folders',
		'This folder and files',
		'Sub-folders and files only',
		'Sub-folders only',
		'Files only' )]
	[String]$AppliesTo = 'This folder, sub-folders and files',
	
	# Whether to allow the described access.
	[Parameter(Mandatory = $true)]
	[Bool]$AllowAccess
)

$ErrorActionPreference = 'Stop'

# Table of InheritanceFlags/PropagationFlags values: https://stackoverflow.com/a/8390274
if($AppliesTo -eq "This folder only")
{
	$InheritanceFlags = 'None'
	$PropagationFlags = 'None'
}
elseif($AppliesTo -eq "This folder, sub-folders and files")
{
	$InheritanceFlags = 'ContainerInherit,ObjectInherit'
	$PropagationFlags = 'None'
}
elseif($AppliesTo -eq "This folder and sub-folders")
{
	$InheritanceFlags = 'ContainerInherit'
	$PropagationFlags = 'None'
}
elseif($AppliesTo -eq "This folder and files")
{
	$InheritanceFlags = 'Object'
	$PropagationFlags = 'None'
}
elseif($AppliesTo -eq "Sub-folders and files only")
{
	$InheritanceFlags = 'ContainerInherit,ObjectInherit'
	$PropagationFlags = 'InheritOnly'
}
elseif($AppliesTo -eq "Sub-folders only")
{
	$InheritanceFlags = 'ContainerInherit'
	$PropagationFlags = 'InheritOnly'
}
elseif($AppliesTo -eq "Files only")
{
	$InheritanceFlags = 'ObjectInherit'
	$PropagationFlags = 'InheritOnly'
}

if($AllowAccess)
{
	$AccessControlType = 'Allow'
}
else{
	$AccessControlType = 'Deny'
}

$acl = Get-Acl $Path

$new_rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
	$Identity,
	$Rights,
	$InheritanceFlags,
	$PropagationFlags,
	$AccessControlType)

$acl.SetAccessRule($new_rule)

Set-Acl $Path $acl
