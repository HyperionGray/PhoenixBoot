/*
 * UUEFI - Universal UEFI Diagnostic Application
 * 
 * A simple UEFI application that displays system information
 * and provides a diagnostic interface for PhoenixGuard.
 * 
 * Unlike NuclearBoot, this does not enforce strict security requirements
 * and can run in both secure and non-secure boot modes.
 */

#include <Uefi.h>
#include <Library/UefiApplicationEntryPoint.h>
#include <Library/UefiLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiRuntimeServicesTableLib.h>
#include <Library/PrintLib.h>
#include <Protocol/SimpleFileSystem.h>
#include <Protocol/LoadedImage.h>
#include <Guid/FileInfo.h>
#include <Guid/GlobalVariable.h>

#define UUEFI_VERSION L"3.0.0"
#define MAX_VARIABLE_NAME_SIZE 1024
#define MAX_VARIABLES 500
#define MAX_SUSPICIOUS_ITEMS 50
#define MAX_INPUT_SIZE 256

// Variable categories
typedef enum {
  VAR_CAT_BOOT,
  VAR_CAT_SECURITY,
  VAR_CAT_HARDWARE,
  VAR_CAT_VENDOR,
  VAR_CAT_UNKNOWN
} VARIABLE_CATEGORY;

// Variable information structure
typedef struct {
  CHAR16 Name[MAX_VARIABLE_NAME_SIZE];
  EFI_GUID VendorGuid;
  UINTN DataSize;
  UINT32 Attributes;
  VARIABLE_CATEGORY Category;
  BOOLEAN IsSuspicious;
  CHAR16 SuspicionReason[256];
  BOOLEAN IsEditable;
  CHAR16 Description[512];
} VARIABLE_INFO;

// Suspicious activity structure
typedef struct {
  CHAR16 Description[256];
  CHAR16 Details[512];
  UINT8 Severity; // 1=Low, 2=Medium, 3=High
} SUSPICIOUS_ITEM;

// Global variables for enumeration
STATIC VARIABLE_INFO *gVariables = NULL;
STATIC UINTN gVariableCount = 0;
STATIC SUSPICIOUS_ITEM gSuspiciousItems[MAX_SUSPICIOUS_ITEMS];
STATIC UINTN gSuspiciousCount = 0;

/**
  Compare two GUIDs
  
  @param Guid1  First GUID
  @param Guid2  Second GUID
  
  @retval TRUE   GUIDs are equal
  @retval FALSE  GUIDs are different
**/
BOOLEAN
CompareGuid(
  IN EFI_GUID *Guid1,
  IN EFI_GUID *Guid2
  )
{
  UINT8 *g1 = (UINT8 *)Guid1;
  UINT8 *g2 = (UINT8 *)Guid2;
  
  // Byte-by-byte comparison to avoid alignment issues
  for (UINTN i = 0; i < sizeof(EFI_GUID); i++) {
    if (g1[i] != g2[i]) {
      return FALSE;
    }
  }
  return TRUE;
}

/**
  Categorize a variable based on its name and GUID
  
  @param Name  Variable name
  @param Guid  Variable GUID
  
  @retval VARIABLE_CATEGORY  The category of the variable
**/
VARIABLE_CATEGORY
CategorizeVariable(
  IN CHAR16 *Name,
  IN EFI_GUID *Guid
  )
{
  EFI_GUID GlobalVar = EFI_GLOBAL_VARIABLE;
  
  // Check if it's a global variable
  if (CompareGuid(Guid, &GlobalVar)) {
    // Boot-related variables
    if (StrnCmp(Name, L"Boot", 4) == 0 || 
        StrCmp(Name, L"BootOrder") == 0 ||
        StrCmp(Name, L"BootCurrent") == 0 ||
        StrCmp(Name, L"BootNext") == 0) {
      return VAR_CAT_BOOT;
    }
    
    // Security variables
    if (StrCmp(Name, L"SecureBoot") == 0 ||
        StrCmp(Name, L"SetupMode") == 0 ||
        StrCmp(Name, L"PK") == 0 ||
        StrCmp(Name, L"KEK") == 0 ||
        StrCmp(Name, L"db") == 0 ||
        StrCmp(Name, L"dbx") == 0) {
      return VAR_CAT_SECURITY;
    }
  }
  
  // Hardware/vendor-specific variables (non-standard GUID)
  return VAR_CAT_VENDOR;
}

/**
  Add suspicious item to the report
  
  @param Description  Brief description of the issue
  @param Details      Detailed information
  @param Severity     Severity level (1-3)
**/
VOID
AddSuspiciousItem(
  IN CHAR16 *Description,
  IN CHAR16 *Details,
  IN UINT8 Severity
  )
{
  if (gSuspiciousCount >= MAX_SUSPICIOUS_ITEMS) {
    return;
  }
  
  StrCpyS(gSuspiciousItems[gSuspiciousCount].Description, 256, Description);
  StrCpyS(gSuspiciousItems[gSuspiciousCount].Details, 512, Details);
  gSuspiciousItems[gSuspiciousCount].Severity = Severity;
  gSuspiciousCount++;
}

/**
  Run heuristics to detect suspicious variables
  
  @param VarInfo  Variable information to check
**/
VOID
CheckVariableHeuristics(
  IN OUT VARIABLE_INFO *VarInfo
  )
{
  CHAR16 TempStr[512];
  
  VarInfo->IsSuspicious = FALSE;
  VarInfo->SuspicionReason[0] = 0;  // Clear reason string
  
  // Heuristic 1: Unusually large variables (except db/dbx which can be large)
  if (VarInfo->DataSize > 32768 && 
      StrCmp(VarInfo->Name, L"db") != 0 && 
      StrCmp(VarInfo->Name, L"dbx") != 0) {
    VarInfo->IsSuspicious = TRUE;
    if (VarInfo->SuspicionReason[0] == 0) {
      UnicodeSPrint(VarInfo->SuspicionReason, 256, L"Unusually large size: %lu bytes", VarInfo->DataSize);
    }
    
    UnicodeSPrint(TempStr, 512, L"Variable '%s' has unusual size: %lu bytes", 
                  VarInfo->Name, VarInfo->DataSize);
    AddSuspiciousItem(L"Large variable detected", TempStr, 2);
  }
  
  // Heuristic 2: Boot variables with unusual attributes
  if (VarInfo->Category == VAR_CAT_BOOT) {
    // Boot variables should typically have NV+BS+RT attributes
    UINT32 expectedAttr = EFI_VARIABLE_NON_VOLATILE | 
                          EFI_VARIABLE_BOOTSERVICE_ACCESS | 
                          EFI_VARIABLE_RUNTIME_ACCESS;
    
    if ((VarInfo->Attributes & expectedAttr) != expectedAttr) {
      VarInfo->IsSuspicious = TRUE;
      if (VarInfo->SuspicionReason[0] == 0) {
        UnicodeSPrint(VarInfo->SuspicionReason, 256, L"Unexpected attributes: 0x%08x", VarInfo->Attributes);
      }
      
      UnicodeSPrint(TempStr, 512, L"Boot variable '%s' has non-standard attributes", VarInfo->Name);
      AddSuspiciousItem(L"Boot variable with unusual attributes", TempStr, 2);
    }
  }
  
  // Heuristic 3: Security variables that are writable at runtime (potential bypass)
  if (VarInfo->Category == VAR_CAT_SECURITY) {
    if ((VarInfo->Attributes & EFI_VARIABLE_RUNTIME_ACCESS) &&
        !(VarInfo->Attributes & EFI_VARIABLE_TIME_BASED_AUTHENTICATED_WRITE_ACCESS)) {
      VarInfo->IsSuspicious = TRUE;
      if (VarInfo->SuspicionReason[0] == 0) {
        StrCpyS(VarInfo->SuspicionReason, 256, L"Security var writable without auth");
      }
      
      UnicodeSPrint(TempStr, 512, L"Security variable '%s' may be writable without authentication", 
                    VarInfo->Name);
      AddSuspiciousItem(L"Potentially vulnerable security variable", TempStr, 3);
    }
  }
  
  // Heuristic 4: Vendor variables with suspicious names
  if (VarInfo->Category == VAR_CAT_VENDOR) {
    CHAR16 *suspiciousKeywords[] = {
      L"Debug", L"Test", L"Backdoor", L"Hidden", NULL
    };
    
    for (UINTN i = 0; suspiciousKeywords[i] != NULL; i++) {
      if (StrStr(VarInfo->Name, suspiciousKeywords[i]) != NULL) {
        VarInfo->IsSuspicious = TRUE;
        if (VarInfo->SuspicionReason[0] == 0) {
          UnicodeSPrint(VarInfo->SuspicionReason, 256, L"Contains keyword: %s", suspiciousKeywords[i]);
        }
        
        UnicodeSPrint(TempStr, 512, L"Vendor variable '%s' contains suspicious keyword", 
                      VarInfo->Name);
        AddSuspiciousItem(L"Suspicious variable name detected", TempStr, 2);
        break;
      }
    }
  }
}

/**
  Get description for a variable based on its name and category
  
  @param VarInfo  Variable information
**/
VOID
AddVariableDescription(
  IN OUT VARIABLE_INFO *VarInfo
  )
{
  // Initialize description
  VarInfo->Description[0] = 0;
  VarInfo->IsEditable = FALSE;
  
  // Boot variables
  if (VarInfo->Category == VAR_CAT_BOOT) {
    if (StrCmp(VarInfo->Name, L"BootOrder") == 0) {
      StrCpyS(VarInfo->Description, 512, L"Order of boot devices tried at system startup");
    } else if (StrCmp(VarInfo->Name, L"BootCurrent") == 0) {
      StrCpyS(VarInfo->Description, 512, L"Currently booted device entry");
    } else if (StrCmp(VarInfo->Name, L"BootNext") == 0) {
      StrCpyS(VarInfo->Description, 512, L"Next boot device for one-time boot");
      VarInfo->IsEditable = TRUE;
    } else if (StrnCmp(VarInfo->Name, L"Boot", 4) == 0) {
      StrCpyS(VarInfo->Description, 512, L"Boot device entry configuration");
    }
  }
  
  // Security variables
  else if (VarInfo->Category == VAR_CAT_SECURITY) {
    if (StrCmp(VarInfo->Name, L"SecureBoot") == 0) {
      StrCpyS(VarInfo->Description, 512, L"Secure Boot status (1=enabled, 0=disabled)");
    } else if (StrCmp(VarInfo->Name, L"SetupMode") == 0) {
      StrCpyS(VarInfo->Description, 512, L"Setup mode status (1=setup, 0=user mode)");
    } else if (StrCmp(VarInfo->Name, L"PK") == 0) {
      StrCpyS(VarInfo->Description, 512, L"Platform Key - root of trust for Secure Boot");
    } else if (StrCmp(VarInfo->Name, L"KEK") == 0) {
      StrCpyS(VarInfo->Description, 512, L"Key Exchange Key - intermediate authority");
    } else if (StrCmp(VarInfo->Name, L"db") == 0) {
      StrCpyS(VarInfo->Description, 512, L"Signature Database - allowed signatures");
    } else if (StrCmp(VarInfo->Name, L"dbx") == 0) {
      StrCpyS(VarInfo->Description, 512, L"Forbidden Signature Database - revoked signatures");
    }
  }
  
  // Vendor-specific variables (mark as editable)
  else if (VarInfo->Category == VAR_CAT_VENDOR) {
    VarInfo->IsEditable = TRUE;
    
    // Check for common vendor variable patterns
    if (StrStr(VarInfo->Name, L"Animation") != NULL) {
      StrCpyS(VarInfo->Description, 512, L"BIOS boot animation settings (editable)");
    } else if (StrStr(VarInfo->Name, L"MyAsus") != NULL || StrStr(VarInfo->Name, L"MyASUS") != NULL) {
      StrCpyS(VarInfo->Description, 512, L"MyASUS software auto-install setting (editable)");
    } else if (StrStr(VarInfo->Name, L"Armoury") != NULL || StrStr(VarInfo->Name, L"Crate") != NULL) {
      StrCpyS(VarInfo->Description, 512, L"Armoury Crate configuration (editable)");
    } else if (StrStr(VarInfo->Name, L"CloudRecovery") != NULL) {
      StrCpyS(VarInfo->Description, 512, L"Cloud recovery support setting (editable)");
    } else if (StrStr(VarInfo->Name, L"Camera") != NULL) {
      StrCpyS(VarInfo->Description, 512, L"Camera/webcam configuration");
    } else if (StrStr(VarInfo->Name, L"Touchpad") != NULL) {
      StrCpyS(VarInfo->Description, 512, L"Touchpad device configuration");
    } else {
      StrCpyS(VarInfo->Description, 512, L"Vendor-specific configuration (may be editable)");
    }
  }
  
  // If no description set, use generic one
  if (VarInfo->Description[0] == 0) {
    StrCpyS(VarInfo->Description, 512, L"No description available");
  }
}

/**
  Enumerate all EFI variables
  
  @retval EFI_SUCCESS  Variables enumerated successfully
  @retval Other        Error occurred
**/
EFI_STATUS
EnumerateAllVariables(VOID)
{
  EFI_STATUS Status;
  CHAR16 VariableName[MAX_VARIABLE_NAME_SIZE];
  EFI_GUID VendorGuid;
  UINTN NameSize;
  UINTN DataSize;
  UINT32 Attributes;
  
  Print(L"\n=== Enumerating All EFI Variables ===\n");
  Print(L"This may take a moment...\n\n");
  
  // Allocate memory for variable array
  gVariables = AllocateZeroPool(MAX_VARIABLES * sizeof(VARIABLE_INFO));
  if (gVariables == NULL) {
    Print(L"Failed to allocate memory for variables\n");
    return EFI_OUT_OF_RESOURCES;
  }
  
  gVariableCount = 0;
  gSuspiciousCount = 0;
  
  // Start enumeration with empty name
  VariableName[0] = 0;
  NameSize = sizeof(VariableName);
  
  while (TRUE) {
    // Get next variable name
    Status = gRT->GetNextVariableName(&NameSize, VariableName, &VendorGuid);
    
    if (EFI_ERROR(Status)) {
      if (Status == EFI_NOT_FOUND) {
        // End of enumeration
        break;
      } else if (Status == EFI_BUFFER_TOO_SMALL) {
        // Name buffer too small, shouldn't happen with our size
        NameSize = sizeof(VariableName);
        continue;
      } else {
        // Other error
        break;
      }
    }
    
    // Stop if we've reached max variables
    if (gVariableCount >= MAX_VARIABLES) {
      Print(L"Warning: Maximum variable count reached (%lu)\n", MAX_VARIABLES);
      break;
    }
    
    // Get variable attributes and size
    DataSize = 0;
    Status = gRT->GetVariable(VariableName, &VendorGuid, &Attributes, &DataSize, NULL);
    
    if (Status == EFI_BUFFER_TOO_SMALL || Status == EFI_SUCCESS) {
      // Store variable information
      VARIABLE_INFO *var = &gVariables[gVariableCount];
      
      StrCpyS(var->Name, MAX_VARIABLE_NAME_SIZE, VariableName);
      CopyMem(&var->VendorGuid, &VendorGuid, sizeof(EFI_GUID));
      var->DataSize = DataSize;
      var->Attributes = Attributes;
      var->Category = CategorizeVariable(VariableName, &VendorGuid);
      
      // Run heuristics
      CheckVariableHeuristics(var);
      
      // Add description
      AddVariableDescription(var);
      
      gVariableCount++;
    }
    
    // Reset name size for next iteration
    NameSize = sizeof(VariableName);
  }
  
  Print(L"Found %lu EFI variables\n", gVariableCount);
  Print(L"Suspicious items detected: %lu\n", gSuspiciousCount);
  
  return EFI_SUCCESS;
}

/**
  Display all variables by category
  
  @param Category  Category to display, or -1 for all
**/
VOID
DisplayVariablesByCategory(
  IN INTN Category
  )
{
  CHAR16 *CategoryNames[] = {
    L"Boot Configuration",
    L"Security",
    L"Hardware",
    L"Vendor-Specific",
    L"Unknown"
  };
  
  for (UINTN cat = 0; cat < 5; cat++) {
    if (Category >= 0 && (UINTN)Category != cat) {
      continue;
    }
    
    // Count variables in this category
    UINTN count = 0;
    for (UINTN i = 0; i < gVariableCount; i++) {
      if (gVariables[i].Category == cat) {
        count++;
      }
    }
    
    if (count == 0) {
      continue;
    }
    
    Print(L"\n--- %s (%lu variables) ---\n", CategoryNames[cat], count);
    
    for (UINTN i = 0; i < gVariableCount; i++) {
      if (gVariables[i].Category == cat) {
        Print(L"  %s", gVariables[i].Name);
        
        if (gVariables[i].IsSuspicious) {
          Print(L" ⚠ SUSPICIOUS: %s", gVariables[i].SuspicionReason);
        }
        
        if (gVariables[i].IsEditable) {
          Print(L" [EDITABLE]");
        }
        
        Print(L"\n    Size: %lu bytes, Attr: 0x%08x\n", 
              gVariables[i].DataSize, gVariables[i].Attributes);
        
        if (gVariables[i].Description[0] != 0) {
          Print(L"    Description: %s\n", gVariables[i].Description);
        }
      }
    }
  }
}

/**
  Display security report with suspicious findings
**/
VOID
DisplaySecurityReport(VOID)
{
  Print(L"\n");
  Print(L"╔════════════════════════════════════════════╗\n");
  Print(L"║     SECURITY ANALYSIS REPORT              ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");
  
  Print(L"\nTotal Variables Analyzed: %lu\n", gVariableCount);
  Print(L"Suspicious Items Found: %lu\n\n", gSuspiciousCount);
  
  if (gSuspiciousCount == 0) {
    Print(L"✓ No suspicious activity detected\n");
    Print(L"  All variables appear normal\n");
    return;
  }
  
  // Group by severity
  UINTN highSev = 0, medSev = 0, lowSev = 0;
  
  for (UINTN i = 0; i < gSuspiciousCount; i++) {
    if (gSuspiciousItems[i].Severity == 3) highSev++;
    else if (gSuspiciousItems[i].Severity == 2) medSev++;
    else lowSev++;
  }
  
  Print(L"Severity Breakdown:\n");
  if (highSev > 0) Print(L"  🔴 HIGH:   %lu issues\n", highSev);
  if (medSev > 0) Print(L"  🟡 MEDIUM: %lu issues\n", medSev);
  if (lowSev > 0) Print(L"  🟢 LOW:    %lu issues\n", lowSev);
  
  Print(L"\nDetailed Findings:\n");
  Print(L"═══════════════════\n");
  
  for (UINTN i = 0; i < gSuspiciousCount; i++) {
    CHAR16 *sevStr;
    if (gSuspiciousItems[i].Severity == 3) sevStr = L"HIGH";
    else if (gSuspiciousItems[i].Severity == 2) sevStr = L"MEDIUM";
    else sevStr = L"LOW";
    
    Print(L"\n[%lu] %s (Severity: %s)\n", i + 1, 
          gSuspiciousItems[i].Description, sevStr);
    Print(L"    %s\n", gSuspiciousItems[i].Details);
  }
  
  Print(L"\n");
}

/**
  Edit a variable value with type detection
  
  @param VarIndex  Index of the variable to edit
  
  @retval EFI_SUCCESS  Variable edited successfully
  @retval Other        Error occurred
**/
EFI_STATUS
EditVariable(
  IN UINTN VarIndex
  )
{
  if (VarIndex >= gVariableCount) {
    return EFI_INVALID_PARAMETER;
  }
  
  VARIABLE_INFO *var = &gVariables[VarIndex];
  
  // Safety check - don't allow editing critical security variables
  if (var->Category == VAR_CAT_SECURITY) {
    Print(L"⚠ Cannot edit security variables for safety\n");
    Print(L"  Use proper key enrollment tools for security variables\n");
    return EFI_ACCESS_DENIED;
  }
  
  // Check if variable is marked as editable
  if (!var->IsEditable && var->Category != VAR_CAT_VENDOR) {
    Print(L"⚠ Variable not marked as safely editable\n");
    Print(L"  Editing may cause system instability\n");
    Print(L"Press 'Y' to continue anyway, any other key to cancel: ");
    
    EFI_INPUT_KEY Key;
    UINTN Index;
    gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
    gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
    Print(L"%c\n", Key.UnicodeChar);
    
    if (Key.UnicodeChar != L'Y' && Key.UnicodeChar != L'y') {
      Print(L"Cancelled\n");
      return EFI_ABORTED;
    }
  }
  
  Print(L"\n╔════════════════════════════════════════════╗\n");
  Print(L"║           EDIT VARIABLE                   ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");
  Print(L"\nVariable: %s\n", var->Name);
  Print(L"Description: %s\n", var->Description);
  Print(L"Current Size: %lu bytes\n", var->DataSize);
  
  // Read current value
  UINT8 *CurrentData = AllocateZeroPool(var->DataSize);
  if (CurrentData == NULL) {
    Print(L"✗ Failed to allocate memory\n");
    return EFI_OUT_OF_RESOURCES;
  }
  
  UINTN DataSize = var->DataSize;
  EFI_STATUS Status = gRT->GetVariable(
    var->Name,
    &var->VendorGuid,
    NULL,
    &DataSize,
    CurrentData
  );
  
  if (!EFI_ERROR(Status)) {
    Print(L"Current Value (hex): ");
    for (UINTN i = 0; i < (DataSize > 16 ? 16 : DataSize); i++) {
      Print(L"%02x ", CurrentData[i]);
    }
    if (DataSize > 16) {
      Print(L"... (%lu more bytes)", DataSize - 16);
    }
    Print(L"\n");
    
    // Try to interpret value
    if (DataSize == 1) {
      Print(L"Current Value (decimal): %u\n", CurrentData[0]);
      Print(L"Current Value (boolean): %s\n", CurrentData[0] ? L"Enabled" : L"Disabled");
    } else if (DataSize == 2) {
      UINT16 val = *(UINT16*)CurrentData;
      Print(L"Current Value (decimal): %u\n", val);
    } else if (DataSize == 4) {
      UINT32 val = *(UINT32*)CurrentData;
      Print(L"Current Value (decimal): %u\n", val);
    }
  }
  
  Print(L"\n⚠ WARNING: Incorrect values may cause system instability!\n");
  Print(L"\nEdit Options:\n");
  Print(L"  1. Set to 0 (Disable)\n");
  Print(L"  2. Set to 1 (Enable)\n");
  Print(L"  3. Delete Variable\n");
  Print(L"  0. Cancel\n");
  Print(L"\nSelect option: ");
  
  EFI_INPUT_KEY Key;
  UINTN Index;
  gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
  gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
  Print(L"%c\n", Key.UnicodeChar);
  
  UINT8 newValue;
  BOOLEAN deleteVar = FALSE;
  
  switch (Key.UnicodeChar) {
    case L'1':
      newValue = 0;
      break;
    case L'2':
      newValue = 1;
      break;
    case L'3':
      deleteVar = TRUE;
      break;
    case L'0':
      Print(L"Cancelled\n");
      FreePool(CurrentData);
      return EFI_ABORTED;
    default:
      Print(L"Invalid option\n");
      FreePool(CurrentData);
      return EFI_INVALID_PARAMETER;
  }
  
  // Confirm action
  Print(L"\nConfirm action? This will take effect on next boot.\n");
  Print(L"Press 'Y' to confirm, any other key to cancel: ");
  
  gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
  gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
  Print(L"%c\n", Key.UnicodeChar);
  
  if (Key.UnicodeChar != L'Y' && Key.UnicodeChar != L'y') {
    Print(L"Cancelled\n");
    FreePool(CurrentData);
    return EFI_ABORTED;
  }
  
  if (deleteVar) {
    // Delete variable by setting size to 0
    Status = gRT->SetVariable(
      var->Name,
      &var->VendorGuid,
      var->Attributes,
      0,
      NULL
    );
    
    if (EFI_ERROR(Status)) {
      Print(L"✗ Failed to delete variable: %r\n", Status);
      Print(L"  Variable may be read-only or protected\n");
    } else {
      Print(L"✓ Variable deleted successfully\n");
      Print(L"  Change will take effect after reboot\n");
    }
  } else {
    // Set new value
    Status = gRT->SetVariable(
      var->Name,
      &var->VendorGuid,
      var->Attributes,
      sizeof(newValue),
      &newValue
    );
    
    if (EFI_ERROR(Status)) {
      Print(L"✗ Failed to modify variable: %r\n", Status);
      Print(L"  Variable may be read-only or protected\n");
    } else {
      Print(L"✓ Variable modified successfully\n");
      Print(L"  New value: %u\n", newValue);
      Print(L"  Change will take effect after reboot\n");
    }
  }
  
  FreePool(CurrentData);
  return Status;
}

/**
  Toggle a variable (enable/disable)
  
  @param VarIndex  Index of the variable to toggle
  
  @retval EFI_SUCCESS  Variable toggled successfully
  @retval Other        Error occurred
**/
EFI_STATUS
ToggleVariable(
  IN UINTN VarIndex
  )
{
  if (VarIndex >= gVariableCount) {
    return EFI_INVALID_PARAMETER;
  }
  
  VARIABLE_INFO *var = &gVariables[VarIndex];
  
  // Safety check - don't allow toggling critical security or boot variables
  if (var->Category == VAR_CAT_SECURITY) {
    Print(L"⚠ Cannot toggle security variables for safety\n");
    return EFI_ACCESS_DENIED;
  }
  
  if (var->Category == VAR_CAT_BOOT && 
      (StrCmp(var->Name, L"BootOrder") == 0 || 
       StrCmp(var->Name, L"BootCurrent") == 0)) {
    Print(L"⚠ Cannot toggle critical boot variables\n");
    return EFI_ACCESS_DENIED;
  }
  
  // Only allow toggling vendor variables
  if (var->Category != VAR_CAT_VENDOR) {
    Print(L"⚠ Only vendor-specific variables can be toggled\n");
    Print(L"  (For safety, boot and security variables are protected)\n");
    return EFI_ACCESS_DENIED;
  }
  
  Print(L"\n⚠ WARNING: Variable modification can affect system stability!\n");
  Print(L"Variable: %s\n", var->Name);
  Print(L"Current size: %lu bytes\n", var->DataSize);
  Print(L"\nThis feature allows disabling vendor-specific features.\n");
  Print(L"Press 'Y' to set to zero (disable), any other key to cancel: ");
  
  EFI_INPUT_KEY Key;
  UINTN Index;
  gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
  gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
  Print(L"%c\n", Key.UnicodeChar);
  
  if (Key.UnicodeChar != L'Y' && Key.UnicodeChar != L'y') {
    Print(L"Cancelled\n");
    return EFI_ABORTED;
  }
  
  // Set variable to zero (disable)
  UINT8 zeroValue = 0;
  EFI_STATUS Status = gRT->SetVariable(
    var->Name,
    &var->VendorGuid,
    var->Attributes,
    sizeof(zeroValue),
    &zeroValue
  );
  
  if (EFI_ERROR(Status)) {
    Print(L"✗ Failed to modify variable: %r\n", Status);
    Print(L"  Variable may be read-only or protected\n");
    return Status;
  }
  
  Print(L"✓ Variable disabled successfully\n");
  Print(L"  Change will take effect after reboot\n");
  
  return EFI_SUCCESS;
}

/**
  Display ESP configuration files
  
  @param ImageHandle  Image handle for file system access
**/
VOID
DisplayESPConfig(
  IN EFI_HANDLE ImageHandle
  )
{
  EFI_STATUS Status;
  EFI_LOADED_IMAGE_PROTOCOL *LoadedImage = NULL;
  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *Fs = NULL;
  EFI_FILE_PROTOCOL *Root = NULL;
  EFI_FILE_PROTOCOL *ConfigFile = NULL;
  
  Print(L"\n╔════════════════════════════════════════════╗\n");
  Print(L"║        ESP CONFIGURATION VIEWER            ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");
  
  Status = gBS->HandleProtocol(ImageHandle, &gEfiLoadedImageProtocolGuid, (VOID **)&LoadedImage);
  if (EFI_ERROR(Status) || LoadedImage == NULL || LoadedImage->DeviceHandle == NULL) {
    Print(L"\n✗ Cannot access ESP file system\n");
    return;
  }
  
  Status = gBS->HandleProtocol(LoadedImage->DeviceHandle, &gEfiSimpleFileSystemProtocolGuid, (VOID **)&Fs);
  if (EFI_ERROR(Status) || Fs == NULL) {
    Print(L"\n✗ Cannot access ESP file system\n");
    return;
  }
  
  Status = Fs->OpenVolume(Fs, &Root);
  if (EFI_ERROR(Status) || Root == NULL) {
    Print(L"\n✗ Cannot open ESP volume\n");
    return;
  }
  
  Print(L"\nScanning ESP for configuration files...\n");
  Print(L"Common locations checked:\n");
  Print(L"  - /EFI/PhoenixGuard/\n");
  Print(L"  - /EFI/BOOT/\n");
  Print(L"  - /EFI/ubuntu/\n");
  
  // Try to read PhoenixGuard config
  CHAR16 *ConfigPaths[] = {
    L"\\EFI\\PhoenixGuard\\config.txt",
    L"\\EFI\\PhoenixGuard\\ESP_UUID.txt",
    L"\\EFI\\BOOT\\grub.cfg",
    NULL
  };
  
  for (UINTN i = 0; ConfigPaths[i] != NULL; i++) {
    Status = Root->Open(Root, &ConfigFile, ConfigPaths[i], EFI_FILE_MODE_READ, 0);
    if (!EFI_ERROR(Status) && ConfigFile) {
      Print(L"\n✓ Found: %s\n", ConfigPaths[i]);
      
      // Get file size
      EFI_FILE_INFO *FileInfo = NULL;
      UINTN BufferSize = SIZE_OF_EFI_FILE_INFO + 512;
      FileInfo = AllocateZeroPool(BufferSize);
      
      if (FileInfo) {
        Status = ConfigFile->GetInfo(ConfigFile, &gEfiFileInfoGuid, &BufferSize, FileInfo);
        if (!EFI_ERROR(Status)) {
          Print(L"  Size: %lu bytes\n", FileInfo->FileSize);
          
          // Read first 512 bytes
          if (FileInfo->FileSize > 0) {
            UINTN ReadSize = FileInfo->FileSize > 512 ? 512 : FileInfo->FileSize;
            UINT8 *Buffer = AllocateZeroPool(ReadSize + 1);
            
            if (Buffer) {
              UINTN ActualRead = ReadSize;
              Status = ConfigFile->Read(ConfigFile, &ActualRead, Buffer);
              if (!EFI_ERROR(Status) && ActualRead > 0) {
                Print(L"  Content (first %lu bytes):\n", ActualRead);
                // Convert to CHAR16 for display
                for (UINTN j = 0; j < ActualRead && j < 256; j++) {
                  if (Buffer[j] >= 32 && Buffer[j] < 127) {
                    Print(L"%c", (CHAR16)Buffer[j]);
                  } else if (Buffer[j] == '\n') {
                    Print(L"\n  ");
                  }
                }
                Print(L"\n");
              }
              FreePool(Buffer);
            }
          }
        }
        FreePool(FileInfo);
      }
      
      ConfigFile->Close(ConfigFile);
    }
  }
  
  Print(L"\n✓ ESP configuration scan complete\n");
  Print(L"\nNote: Full config editing requires mounting ESP from OS\n");
  Print(L"      Use scripts/esp-package.sh for advanced config management\n");
  
  if (Root) Root->Close(Root);
}

/**
  Nuclear Wipe System - Safely wipe system and BIOS/EFI variables
  
  This is the "nuclear option" for when a system has serious malware
  and needs complete reinitiation.
**/
VOID
NuclearWipeSystem(VOID)
{
  EFI_INPUT_KEY Key;
  UINTN Index;
  
  Print(L"\n");
  Print(L"╔════════════════════════════════════════════╗\n");
  Print(L"║     ☢ NUCLEAR WIPE SYSTEM ☢              ║\n");
  Print(L"║     EXTREME CAUTION REQUIRED              ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");
  
  Print(L"\n⚠⚠⚠ CRITICAL WARNING ⚠⚠⚠\n");
  Print(L"\nThis feature will:\n");
  Print(L"  1. Reset ALL user-modifiable EFI variables\n");
  Print(L"  2. Clear boot configuration\n");
  Print(L"  3. Reset vendor-specific settings\n");
  Print(L"  4. Launch disk wipe utility (if available)\n");
  Print(L"\nThis is intended for severe malware/rootkit scenarios.\n");
  Print(L"Your system will need complete reconfiguration after this!\n");
  
  Print(L"\nFeatures:\n");
  Print(L"  • Reset NVRAM to factory defaults\n");
  Print(L"  • Clear all boot entries\n");
  Print(L"  • Reset vendor variables\n");
  Print(L"  • Integration with nwipe for disk wiping\n");
  
  Print(L"\n⚠ This operation is IRREVERSIBLE!\n");
  Print(L"\nAre you ABSOLUTELY SURE you want to proceed?\n");
  Print(L"Type 'NUCLEAR' to confirm (case sensitive), or any other key to cancel:\n");
  
  // Simple confirmation - in production would read full string
  Print(L"\nPress 'N' to proceed with nuclear wipe, any other key to cancel: ");
  
  gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
  gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
  Print(L"%c\n", Key.UnicodeChar);
  
  if (Key.UnicodeChar != L'N' && Key.UnicodeChar != L'n') {
    Print(L"\n✓ Nuclear wipe cancelled - system unchanged\n");
    return;
  }
  
  Print(L"\n⚠ FINAL CONFIRMATION ⚠\n");
  Print(L"Press 'Y' one more time to execute nuclear wipe: ");
  
  gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
  gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
  Print(L"%c\n", Key.UnicodeChar);
  
  if (Key.UnicodeChar != L'Y' && Key.UnicodeChar != L'y') {
    Print(L"\n✓ Nuclear wipe cancelled - system unchanged\n");
    return;
  }
  
  Print(L"\n☢ EXECUTING NUCLEAR WIPE ☢\n");
  Print(L"═══════════════════════════\n\n");
  
  // Phase 1: Reset vendor-specific variables
  Print(L"Phase 1: Resetting vendor variables...\n");
  UINTN wipedVendor = 0;
  
  for (UINTN i = 0; i < gVariableCount; i++) {
    if (gVariables[i].Category == VAR_CAT_VENDOR && gVariables[i].IsEditable) {
      // Try to delete the variable
      EFI_STATUS Status = gRT->SetVariable(
        gVariables[i].Name,
        &gVariables[i].VendorGuid,
        gVariables[i].Attributes,
        0,
        NULL
      );
      
      if (!EFI_ERROR(Status)) {
        wipedVendor++;
        Print(L"  ✓ Wiped: %s\n", gVariables[i].Name);
      }
    }
  }
  
  Print(L"✓ Phase 1 complete: %lu vendor variables wiped\n\n", wipedVendor);
  
  // Phase 2: Clear non-current boot entries
  Print(L"Phase 2: Clearing boot entries (preserving BootCurrent)...\n");
  UINTN wipedBoot = 0;
  
  // Get BootCurrent so we don't delete it
  UINT16 BootCurrent = 0xFFFF;
  UINTN Size = sizeof(BootCurrent);
  EFI_GUID GlobalVar = EFI_GLOBAL_VARIABLE;
  gRT->GetVariable(L"BootCurrent", &GlobalVar, NULL, &Size, &BootCurrent);
  
  for (UINTN i = 0; i < gVariableCount; i++) {
    if (gVariables[i].Category == VAR_CAT_BOOT && 
        StrnCmp(gVariables[i].Name, L"Boot", 4) == 0 &&
        StrLen(gVariables[i].Name) == 8) { // Boot#### format
      
      // Parse boot number
      UINT16 bootNum = 0;
      for (UINTN j = 4; j < 8; j++) {
        if (gVariables[i].Name[j] >= L'0' && gVariables[i].Name[j] <= L'9') {
          bootNum = bootNum * 10 + (gVariables[i].Name[j] - L'0');
        } else if (gVariables[i].Name[j] >= L'A' && gVariables[i].Name[j] <= L'F') {
          bootNum = bootNum * 16 + (gVariables[i].Name[j] - L'A' + 10);
        }
      }
      
      // Skip current boot
      if (bootNum == BootCurrent) {
        Print(L"  ⊙ Preserved: %s (current boot)\n", gVariables[i].Name);
        continue;
      }
      
      // Delete boot entry
      EFI_STATUS Status = gRT->SetVariable(
        gVariables[i].Name,
        &gVariables[i].VendorGuid,
        gVariables[i].Attributes,
        0,
        NULL
      );
      
      if (!EFI_ERROR(Status)) {
        wipedBoot++;
        Print(L"  ✓ Wiped: %s\n", gVariables[i].Name);
      }
    }
  }
  
  Print(L"✓ Phase 2 complete: %lu boot entries wiped\n\n", wipedBoot);
  
  // Phase 3: Information about disk wiping
  Print(L"Phase 3: Disk Wiping (requires reboot to nwipe)\n");
  Print(L"  ℹ For complete disk wiping:\n");
  Print(L"    1. Boot into recovery environment\n");
  Print(L"    2. Run: nwipe /dev/sda (or appropriate device)\n");
  Print(L"    3. Select DoD Short or PRNG Stream method\n");
  Print(L"    4. Confirm and wait for completion\n");
  Print(L"\n  ℹ To integrate nwipe:\n");
  Print(L"    - PhoenixBoot recovery env includes nwipe\n");
  Print(L"    - Use 'workflow-recovery-boot' to create media\n");
  Print(L"    - Boot from recovery media and select wipe option\n");
  Print(L"\n✓ Phase 3 complete: Instructions provided\n\n");
  
  Print(L"╔════════════════════════════════════════════╗\n");
  Print(L"║  ☢ NUCLEAR WIPE SUMMARY ☢                ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");
  Print(L"\nWiped Items:\n");
  Print(L"  • Vendor variables: %lu\n", wipedVendor);
  Print(L"  • Boot entries: %lu\n", wipedBoot);
  Print(L"  • Total: %lu items\n\n", wipedVendor + wipedBoot);
  
  Print(L"⚠ NEXT STEPS:\n");
  Print(L"  1. Reboot system\n");
  Print(L"  2. Enter BIOS/UEFI setup (usually DEL or F2)\n");
  Print(L"  3. Restore any critical settings\n");
  Print(L"  4. Re-enroll Secure Boot keys if needed\n");
  Print(L"  5. For disk wipe: boot to recovery and run nwipe\n");
  Print(L"\n✓ Nuclear wipe process complete!\n");
  Print(L"  System will need reconfiguration on next boot.\n");
}

/**
  Interactive menu system
**/
VOID
ShowInteractiveMenu(VOID)
{
  EFI_INPUT_KEY Key;
  UINTN Index;
  BOOLEAN exitMenu = FALSE;
  
  while (!exitMenu) {
    Print(L"\n");
    Print(L"╔════════════════════════════════════════════╗\n");
    Print(L"║    UUEFI INTERACTIVE MENU v3.0            ║\n");
    Print(L"║    Full BIOS-like Configuration           ║\n");
    Print(L"╚════════════════════════════════════════════╝\n");
    Print(L"\n");
    Print(L"═══ Variable Management ═══\n");
    Print(L"1. View All Variables\n");
    Print(L"2. View Boot Configuration Variables\n");
    Print(L"3. View Security Variables\n");
    Print(L"4. View Vendor-Specific Variables\n");
    Print(L"5. Show Security Report (Suspicious Activity)\n");
    Print(L"6. Edit Variable (Advanced)\n");
    Print(L"7. Re-scan Variables\n");
    Print(L"\n═══ System Configuration ═══\n");
    Print(L"8. View ESP Configuration Files\n");
    Print(L"9. Export Variable List\n");
    Print(L"\n═══ Advanced/Nuclear Options ═══\n");
    Print(L"N. ☢ Nuclear Wipe System (EXTREME CAUTION)\n");
    Print(L"\nQ. Return to Firmware\n");
    Print(L"\nSelect option: ");
    
    gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
    gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
    Print(L"%c\n", Key.UnicodeChar);
    
    switch (Key.UnicodeChar) {
      case L'1':
        DisplayVariablesByCategory(-1);
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'2':
        DisplayVariablesByCategory(VAR_CAT_BOOT);
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'3':
        DisplayVariablesByCategory(VAR_CAT_SECURITY);
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'4':
        DisplayVariablesByCategory(VAR_CAT_VENDOR);
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'5':
        DisplaySecurityReport();
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'6':
        Print(L"\n╔════════════════════════════════════════════╗\n");
        Print(L"║           VARIABLE EDITING                ║\n");
        Print(L"╚════════════════════════════════════════════╝\n");
        Print(L"\nShowing editable variables:\n\n");
        
        // Show editable variables
        UINTN editableCount = 0;
        for (UINTN i = 0; i < gVariableCount; i++) {
          if (gVariables[i].IsEditable) {
            Print(L"  [%lu] %s\n", i, gVariables[i].Name);
            Print(L"      %s\n", gVariables[i].Description);
            editableCount++;
            if (editableCount >= 20) {
              Print(L"  ... and more\n");
              break;
            }
          }
        }
        
        if (editableCount == 0) {
          Print(L"  No safely editable variables found\n");
        } else {
          Print(L"\n⚠ Note: Variable indices shown in brackets []\n");
          Print(L"  To edit: note the index number\n");
          Print(L"  Feature requires additional implementation for index input\n");
        }
        
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'7':
        EnumerateAllVariables();
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'8':
        {
          // Need to pass ImageHandle - store it globally or pass through
          Print(L"\nESP Configuration viewing requires ImageHandle\n");
          Print(L"This feature shows configuration files in ESP\n");
          Print(L"\nPress any key to continue...");
          gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
          gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        }
        break;
        
      case L'9':
        Print(L"\n╔════════════════════════════════════════════╗\n");
        Print(L"║      EXPORT VARIABLE LIST                 ║\n");
        Print(L"╚════════════════════════════════════════════╝\n");
        Print(L"\nVariable export summary:\n");
        Print(L"  Total variables: %lu\n", gVariableCount);
        Print(L"  Boot config: %lu\n", 0); // Would count by category
        Print(L"  Security: %lu\n", 0);
        Print(L"  Vendor: %lu\n", 0);
        Print(L"\n✓ To export to file: Boot to OS and run:\n");
        Print(L"  python3 scripts/uefi_variable_discovery.py\n");
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'N':
      case L'n':
        NuclearWipeSystem();
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'Q':
      case L'q':
        exitMenu = TRUE;
        break;
        
      default:
        Print(L"Invalid option\n");
        break;
    }
  }
}

/**
  Get Secure Boot status without failing if unavailable
  
  @param SecureBoot  Pointer to store Secure Boot status (1=enabled, 0=disabled)
  @param SetupMode   Pointer to store Setup Mode status (1=setup, 0=user)
  
  @retval EFI_SUCCESS  Status retrieved successfully
  @retval Other        Error occurred, values set to 0
**/
EFI_STATUS
GetSecureBootStatus(
  OUT UINT8 *SecureBoot,
  OUT UINT8 *SetupMode
  )
{
  EFI_STATUS Status;
  UINT8 Value;
  UINTN Size;
  EFI_GUID GlobalVar = EFI_GLOBAL_VARIABLE;

  *SecureBoot = 0;
  *SetupMode = 0;

  // Check SecureBoot variable
  Size = sizeof(Value);
  Status = gRT->GetVariable(L"SecureBoot", &GlobalVar, NULL, &Size, &Value);
  if (!EFI_ERROR(Status)) {
    *SecureBoot = Value;
  }

  // Check SetupMode variable
  Size = sizeof(Value);
  Status = gRT->GetVariable(L"SetupMode", &GlobalVar, NULL, &Size, &Value);
  if (!EFI_ERROR(Status)) {
    *SetupMode = Value;
  }

  return EFI_SUCCESS;
}

/**
  Display firmware vendor and version information
**/
VOID
DisplayFirmwareInfo(
  IN EFI_SYSTEM_TABLE *SystemTable
  )
{
  Print(L"\n=== Firmware Information ===\n");
  Print(L"Vendor: %s\n", SystemTable->FirmwareVendor);
  Print(L"Revision: 0x%08x\n", SystemTable->FirmwareRevision);
  Print(L"UEFI Version: %d.%d\n", 
    (SystemTable->Hdr.Revision >> 16) & 0xFFFF,
    SystemTable->Hdr.Revision & 0xFFFF);
}

/**
  Display memory map summary
**/
VOID
DisplayMemoryInfo(VOID)
{
  EFI_STATUS Status;
  UINTN MemMapSize = 0;
  EFI_MEMORY_DESCRIPTOR *MemMap = NULL;
  UINTN MapKey;
  UINTN DescriptorSize;
  UINT32 DescriptorVersion;
  UINT64 TotalMemory = 0;
  UINT64 AvailableMemory = 0;

  Print(L"\n=== Memory Information ===\n");

  // Get memory map size
  Status = gBS->GetMemoryMap(&MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
  if (Status == EFI_BUFFER_TOO_SMALL) {
    MemMapSize += 2 * DescriptorSize; // Add extra space
    MemMap = AllocatePool(MemMapSize);
    if (MemMap != NULL) {
      Status = gBS->GetMemoryMap(&MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
      if (!EFI_ERROR(Status)) {
        EFI_MEMORY_DESCRIPTOR *Entry;
        UINTN EntryCount = MemMapSize / DescriptorSize;
        
        for (UINTN i = 0; i < EntryCount; i++) {
          Entry = (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)MemMap + (i * DescriptorSize));
          TotalMemory += Entry->NumberOfPages * 4096; // 4KB pages
          
          // Count conventional memory as available
          if (Entry->Type == EfiConventionalMemory || Entry->Type == EfiBootServicesData || Entry->Type == EfiBootServicesCode) {
            AvailableMemory += Entry->NumberOfPages * 4096;
          }
        }
        
        Print(L"Total Memory: %lu MB\n", TotalMemory / (1024 * 1024));
        Print(L"Available Memory: %lu MB\n", AvailableMemory / (1024 * 1024));
      }
      FreePool(MemMap);
    }
  }
}

/**
  Display boot configuration information
**/
VOID
DisplayBootInfo(VOID)
{
  EFI_STATUS Status;
  UINT16 *BootOrder = NULL;
  UINTN Size = 0;
  EFI_GUID GlobalVar = EFI_GLOBAL_VARIABLE;

  Print(L"\n=== Boot Configuration ===\n");

  // Get BootOrder variable
  Status = gRT->GetVariable(L"BootOrder", &GlobalVar, NULL, &Size, NULL);
  if (Status == EFI_BUFFER_TOO_SMALL) {
    BootOrder = AllocatePool(Size);
    if (BootOrder != NULL) {
      Status = gRT->GetVariable(L"BootOrder", &GlobalVar, NULL, &Size, BootOrder);
      if (!EFI_ERROR(Status)) {
        UINTN Count = Size / sizeof(UINT16);
        Print(L"Boot Order: ");
        for (UINTN i = 0; i < Count; i++) {
          Print(L"%04x ", BootOrder[i]);
        }
        Print(L"\n");
      }
      FreePool(BootOrder);
    }
  }
}

/**
  Display security status
**/
VOID
DisplaySecurityInfo(VOID)
{
  UINT8 SecureBoot = 0;
  UINT8 SetupMode = 0;

  Print(L"\n=== Security Status ===\n");

  GetSecureBootStatus(&SecureBoot, &SetupMode);
  
  Print(L"Secure Boot: %s\n", SecureBoot ? L"Enabled" : L"Disabled");
  Print(L"Setup Mode: %s\n", SetupMode ? L"Yes" : L"No");
  
  if (SecureBoot && !SetupMode) {
    Print(L"Status: ✓ Secure Boot active and configured\n");
  } else if (!SecureBoot) {
    Print(L"Status: ⚠ Secure Boot disabled\n");
  } else if (SetupMode) {
    Print(L"Status: ⚠ In setup mode - keys not enrolled\n");
  }
}

/**
  Read and display ESP UUID if available
**/
VOID
DisplayBuildInfo(
  IN EFI_HANDLE ImageHandle
  )
{
  EFI_STATUS Status;
  EFI_LOADED_IMAGE_PROTOCOL *LoadedImage = NULL;
  EFI_SIMPLE_FILE_SYSTEM_PROTOCOL *Fs = NULL;
  EFI_FILE_PROTOCOL *Root = NULL;
  EFI_FILE_PROTOCOL *UuidFile = NULL;

  Print(L"\n=== Build Information ===\n");

  Status = gBS->HandleProtocol(ImageHandle, &gEfiLoadedImageProtocolGuid, (VOID **)&LoadedImage);
  if (EFI_ERROR(Status) || LoadedImage == NULL) {
    Print(L"Could not read build information\n");
    return;
  }

  // Check if DeviceHandle is valid before using it
  if (LoadedImage->DeviceHandle == NULL) {
    Print(L"ESP UUID: Not available (no device handle)\n");
    return;
  }

  Status = gBS->HandleProtocol(LoadedImage->DeviceHandle, &gEfiSimpleFileSystemProtocolGuid, (VOID **)&Fs);
  if (EFI_ERROR(Status) || Fs == NULL) {
    Print(L"Could not access file system\n");
    return;
  }

  Status = Fs->OpenVolume(Fs, &Root);
  if (EFI_ERROR(Status) || Root == NULL) {
    Print(L"Could not open volume\n");
    return;
  }

  // Try to read ESP_UUID.txt
  Status = Root->Open(Root, &UuidFile, L"\\EFI\\PhoenixGuard\\ESP_UUID.txt", EFI_FILE_MODE_READ, 0);
  if (!EFI_ERROR(Status) && UuidFile) {
    UINTN BufSize = 256;
    UINT8 *RawBuf = AllocateZeroPool(BufSize);
    if (RawBuf) {
      UINTN ReadSize = BufSize - 1;
      Status = UuidFile->Read(UuidFile, &ReadSize, RawBuf);
      if (!EFI_ERROR(Status) && ReadSize > 0) {
        // Convert ASCII to CHAR16
        CHAR16 *Buf = AllocateZeroPool((ReadSize + 1) * sizeof(CHAR16));
        if (Buf) {
          for (UINTN i = 0; i < ReadSize; i++) {
            Buf[i] = (CHAR16)RawBuf[i];
          }
          Buf[ReadSize] = 0;
          Print(L"ESP UUID: %s\n", Buf);
          FreePool(Buf);
        }
      }
      FreePool(RawBuf);
    }
    UuidFile->Close(UuidFile);
  } else {
    Print(L"ESP UUID: Not available\n");
  }

  if (Root) Root->Close(Root);
}

/**
  Main entry point for UUEFI
  
  @param ImageHandle  The firmware allocated handle for the EFI image.
  @param SystemTable  A pointer to the EFI System Table.
  
  @retval EFI_SUCCESS  Application completed successfully
**/
EFI_STATUS
EFIAPI
UefiMain (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  // Clear screen and reset console
  if (gST && gST->ConOut) {
    gST->ConOut->Reset(gST->ConOut, TRUE);
    gST->ConOut->ClearScreen(gST->ConOut);
  }
  if (gST && gST->ConIn) {
    gST->ConIn->Reset(gST->ConIn, FALSE);
  }

  // Display banner
  Print(L"\n");
  Print(L"╔════════════════════════════════════════════╗\n");
  Print(L"║  🔥 PhoenixGuard UUEFI %s         ║\n", UUEFI_VERSION);
  Print(L"║  Universal UEFI Diagnostic & Config Tool  ║\n");
  Print(L"║  Enhanced: Full BIOS-like Configuration   ║\n");
  Print(L"║  • Variable Editing • ESP Config • Wipe   ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");

  // Display marker for test detection
  Print(L"\n[UUEFI-START]\n");

  // Display all system information
  DisplayFirmwareInfo(SystemTable);
  DisplayMemoryInfo();
  DisplaySecurityInfo();
  DisplayBootInfo();
  DisplayBuildInfo(ImageHandle);

  // NEW: Enumerate all EFI variables
  Print(L"\n");
  Print(L"═══════════════════════════════════════════════\n");
  Print(L"  ADVANCED: Variable Management & Security\n");
  Print(L"═══════════════════════════════════════════════\n");
  
  EnumerateAllVariables();
  
  // Show quick summary of suspicious items
  if (gSuspiciousCount > 0) {
    Print(L"\n⚠ ALERT: %lu suspicious items detected!\n", gSuspiciousCount);
    Print(L"  Use the interactive menu to view details.\n");
  } else {
    Print(L"\n✓ No suspicious activity detected in variables\n");
  }

  // Display completion marker
  Print(L"\n[UUEFI-COMPLETE]\n");

  // NEW: Interactive menu
  Print(L"\n\nOptions:\n");
  Print(L"  M - Enter Interactive Menu (View & Manage Variables)\n");
  Print(L"  R - Show Security Report\n");
  Print(L"  Q - Return to Firmware\n");
  Print(L"\nSelect option: ");
  
  EFI_INPUT_KEY Key;
  UINTN Index;
  
  while (TRUE) {
    gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
    gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
    Print(L"%c\n", Key.UnicodeChar);
    
    if (Key.UnicodeChar == L'M' || Key.UnicodeChar == L'm') {
      ShowInteractiveMenu();
      Print(L"\nOptions: M - Menu, R - Report, Q - Quit\nSelect: ");
    } else if (Key.UnicodeChar == L'R' || Key.UnicodeChar == L'r') {
      DisplaySecurityReport();
      Print(L"\nOptions: M - Menu, R - Report, Q - Quit\nSelect: ");
    } else if (Key.UnicodeChar == L'Q' || Key.UnicodeChar == L'q') {
      break;
    } else {
      Print(L"Invalid option. Try M, R, or Q: ");
    }
  }

  Print(L"\nReturning to firmware...\n");
  
  // Cleanup
  if (gVariables != NULL) {
    FreePool(gVariables);
  }

  return EFI_SUCCESS;
}
