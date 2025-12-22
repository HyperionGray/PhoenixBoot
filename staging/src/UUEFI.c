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

#define UUEFI_VERSION L"3.1.0"
#define MAX_VARIABLE_NAME_SIZE 1024
#define MAX_VARIABLES 500
#define MAX_SUSPICIOUS_ITEMS 50
#define MAX_DESCRIPTION_SIZE 512
#define MAX_DISPLAYED_DELETIONS 10
#define MAX_BACKUP_VARIABLES 10

// UEFI Variable Protection System
typedef enum {
  PROTECTION_DISABLED,
  PROTECTION_ENABLED,
  PROTECTION_EMERGENCY
} PROTECTION_STATE;

// Variable backup structure
typedef struct {
  CHAR16 Name[MAX_VARIABLE_NAME_SIZE];
  EFI_GUID VendorGuid;
  UINT32 Attributes;
  UINTN DataSize;
  VOID *Data;
  BOOLEAN IsValid;
} VARIABLE_BACKUP;

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
  CHAR16 Description[MAX_DESCRIPTION_SIZE];
  BOOLEAN IsEditable;
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
  Describe a variable based on known patterns and names
  
  @param VarInfo  Variable information to populate with description
**/
VOID
DescribeVariable(
  IN OUT VARIABLE_INFO *VarInfo
  )
{
  // Clear description
  ZeroMem(VarInfo->Description, MAX_DESCRIPTION_SIZE * sizeof(CHAR16));
  VarInfo->IsEditable = FALSE;
  
  // Boot variables
  if (VarInfo->Category == VAR_CAT_BOOT) {
    if (StrCmp(VarInfo->Name, L"BootOrder") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Boot device order sequence");
    } else if (StrCmp(VarInfo->Name, L"BootCurrent") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Currently booted device entry");
    } else if (StrCmp(VarInfo->Name, L"BootNext") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Next boot device (one-time)");
    } else if (StrnCmp(VarInfo->Name, L"Boot", 4) == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Boot device entry configuration");
    }
    return;
  }
  
  // Security variables
  if (VarInfo->Category == VAR_CAT_SECURITY) {
    if (StrCmp(VarInfo->Name, L"SecureBoot") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Secure Boot enabled/disabled status");
    } else if (StrCmp(VarInfo->Name, L"SetupMode") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Firmware in setup mode for key enrollment");
    } else if (StrCmp(VarInfo->Name, L"PK") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Platform Key (root of trust)");
    } else if (StrCmp(VarInfo->Name, L"KEK") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Key Exchange Key database");
    } else if (StrCmp(VarInfo->Name, L"db") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Authorized signature database (whitelist)");
    } else if (StrCmp(VarInfo->Name, L"dbx") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Forbidden signature database (blacklist)");
    }
    return;
  }
  
  // Vendor-specific patterns
  if (VarInfo->Category == VAR_CAT_VENDOR) {
    // ASUS-specific variables
    if (StrStr(VarInfo->Name, L"Asus") != NULL) {
      if (StrStr(VarInfo->Name, L"Animation") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"ASUS: BIOS UI animations control");
        VarInfo->IsEditable = TRUE;
      } else if (StrStr(VarInfo->Name, L"Myasus") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"ASUS: MyASUS software auto-install");
        VarInfo->IsEditable = TRUE;
      } else if (StrStr(VarInfo->Name, L"Camera") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"ASUS: Camera security and privacy");
      } else if (StrStr(VarInfo->Name, L"Gnvs") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"ASUS: ACPI Global NVS variables");
      } else if (StrStr(VarInfo->Name, L"Armoury") != NULL || StrStr(VarInfo->Name, L"ArmouryCrate") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"ASUS: ROG Armoury Crate gaming config");
        VarInfo->IsEditable = TRUE;
      } else if (StrStr(VarInfo->Name, L"TouchPad") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"ASUS: Touchpad device configuration");
      } else {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"ASUS vendor-specific configuration");
        VarInfo->IsEditable = TRUE;
      }
      return;
    }
    
    // Intel-specific variables
    if (StrStr(VarInfo->Name, L"Intel") != NULL || StrnCmp(VarInfo->Name, L"Cnv", 3) == 0) {
      if (StrStr(VarInfo->Name, L"Wlan") != NULL || StrStr(VarInfo->Name, L"Wifi") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Intel: WiFi configuration");
        VarInfo->IsEditable = TRUE;
      } else if (StrStr(VarInfo->Name, L"Bt") != NULL || StrStr(VarInfo->Name, L"Bluetooth") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Intel: Bluetooth configuration");
        VarInfo->IsEditable = TRUE;
      } else if (StrStr(VarInfo->Name, L"Vmd") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Intel: VMD NVMe RAID configuration");
      } else if (StrStr(VarInfo->Name, L"Rst") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Intel: Rapid Storage Technology");
      } else {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Intel hardware configuration");
      }
      return;
    }
    
    // Wireless/Network patterns
    if (StrCmp(VarInfo->Name, L"WRDS") == 0 || StrCmp(VarInfo->Name, L"WRDD") == 0 ||
        StrCmp(VarInfo->Name, L"WGDS") == 0 || StrCmp(VarInfo->Name, L"EWRD") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"WiFi regulatory domain settings");
      VarInfo->IsEditable = TRUE;
      return;
    }
    if (StrCmp(VarInfo->Name, L"SADS") == 0 || StrCmp(VarInfo->Name, L"BRDS") == 0) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Bluetooth regulatory settings");
      VarInfo->IsEditable = TRUE;
      return;
    }
    
    // Memory-related
    if (StrStr(VarInfo->Name, L"Memory") != NULL) {
      if (StrStr(VarInfo->Name, L"Overwrite") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Memory overwrite request (security)");
      } else if (StrStr(VarInfo->Name, L"Retrain") != NULL) {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Memory training control");
        VarInfo->IsEditable = TRUE;
      } else {
        StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Memory configuration");
      }
      return;
    }
    
    // Recovery/Cloud features
    if (StrStr(VarInfo->Name, L"Recovery") != NULL || StrStr(VarInfo->Name, L"Cloud") != NULL) {
      StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Cloud recovery service configuration");
      VarInfo->IsEditable = TRUE;
      return;
    }
    
    // Generic vendor variable
    StrCpyS(VarInfo->Description, MAX_DESCRIPTION_SIZE, L"Vendor-specific feature or setting");
    VarInfo->IsEditable = TRUE;
  }
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
      
      // Describe the variable
      DescribeVariable(var);
      
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
        Print(L"  [%lu] %s", i, gVariables[i].Name);
        
        if (gVariables[i].IsSuspicious) {
          Print(L" ⚠ SUSPICIOUS: %s", gVariables[i].SuspicionReason);
        }
        
        if (gVariables[i].IsEditable) {
          Print(L" ✎");
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
  Nuclear Wipe Menu - Complete system reset with NVRAM wipe
  
  This provides a "nuclear option" for complete system reset:
  - Warns user about data loss
  - Optionally wipes all n\n", var->DataSize);
    Print(L"  Attributes: 0x%08x\n", var->Attributes);
    
    // Decode attributes
    Print(L"  Flags: ");
    if (var->Attributes & EFI_VARIABLE_NON_VOLATILE) Print(L"NV ");
    if (var->Attributes & EFI_VARIABLE_BOOTSERVICE_ACCESS) Print(L"BS ");
    if (var->Attributes & EFI_VARIABLE_RUNTIME_ACCESS) Print(L"RT ");
    if (var->Attributes & EFI_VARIABLE_HARDWARE_ERROR_RECORD) Print(L"HW_ERR ");
    if (var->Attributes & EFI_VARIABLE_AUTHENTICATED_WRITE_ACCESS) Print(L"AUTH_WR ");
    if (var->Attributes & EFI_VARIABLE_TIME_BASED_AUTHENTICATED_WRITE_ACCESS) Print(L"TIME_AUTH ");
    if (var->Attributes & EFI_VARIABLE_APPEND_WRITE) Print(L"APPEND ");
    Print(L"\n");
    
    if (var->Description[0] != 0) {
      Print(L"  Description: %s\n", var->Description);
    }
    
    // Dump the actual data
    DumpVariableData(var);
    
    Print(L"\n");
    
    // Pause every 5 variables to avoid overwhelming output
    if ((i + 1) % 5 == 0 && (i + 1) < gVariableCount) {
      Print(L"--- Showing %lu of %lu variables. Press any key to continue... ---\n", i + 1, gVariableCount);
      EFI_INPUT_KEY Key;
      UINTN Index;
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      if (Key.UnicodeChar == L'q' || Key.UnicodeChar == L'Q') {
        Print(L"Dump cancelled by user.\n");
        return;
      }
    }
  }
  
  Print(L"\n✓ Complete variable dump finished.\n");
}

/**
  Enumerate and display all UEFI protocols installed in the system
**/
VOID
ShowProtocolDatabase(VOID)
{
  EFI_STATUS Status;
  UINTN HandleCount = 0;
  EFI_HANDLE *HandleBuffer = NULL;
  
  Print(L"\n");
  Print(L"╔════════════════════════════════════════════╗\n");
  Print(L"║   DEBUG: PROTOCOL DATABASE ENUMERATION    ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");
  Print(L"\n");
  
  // Get all handles
  Status = gBS->LocateHandleBuffer(
    AllHandles,
    NULL,
    NULL,
    &HandleCount,
    &HandleBuffer
  );
  
  if (EFI_ERROR(Status)) {
    Print(L"Failed to enumerate handles: %r\n", Status);
    return;
  }
  
  Print(L"Found %lu handles in system\n\n", HandleCount);
  
  // For each handle, enumerate its protocols
  for (UINTN i = 0; i < HandleCount; i++) {
    EFI_GUID **ProtocolGuidArray = NULL;
    UINTN ProtocolCount = 0;
    
    Status = gBS->ProtocolsPerHandle(
      HandleBuffer[i],
      &ProtocolGuidArray,
      &ProtocolCount
    );
    
    if (!EFI_ERROR(Status) && ProtocolCount > 0) {
      Print(L"Handle[%lu]: %p (%lu protocols)\n", i, HandleBuffer[i], ProtocolCount);
      
      for (UINTN j = 0; j < ProtocolCount; j++) {
        Print(L"  Protocol[%lu]: %08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x\n",
              j,
              ProtocolGuidArray[j]->Data1,
              ProtocolGuidArray[j]->Data2,
              ProtocolGuidArray[j]->Data3,
              ProtocolGuidArray[j]->Data4[0],
              ProtocolGuidArray[j]->Data4[1],
              ProtocolGuidArray[j]->Data4[2],
              ProtocolGuidArray[j]->Data4[3],
              ProtocolGuidArray[j]->Data4[4],
              ProtocolGuidArray[j]->Data4[5],
              ProtocolGuidArray[j]->Data4[6],
              ProtocolGuidArray[j]->Data4[7]);
      }
      
      FreePool(ProtocolGuidArray);
    }
    
    // Pause every 10 handles
    if ((i + 1) % 10 == 0 && (i + 1) < HandleCount) {
      Print(L"\n--- Showing %lu of %lu handles. Press any key to continue (Q to quit)... ---\n", i + 1, HandleCount);
      EFI_INPUT_KEY Key;
      UINTN Index;
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      if (Key.UnicodeChar == L'q' || Key.UnicodeChar == L'Q') {
        Print(L"Enumeration cancelled by user.\n");
        break;
      }
      Print(L"\n");
    }
  }
  
  FreePool(HandleBuffer);
  Print(L"\n✓ Protocol database enumeration complete.\n");
}

/**
  Display system configuration tables
**/
VOID
ShowConfigurationTables(VOID)
{
  Print(L"\n");
  Print(L"╔════════════════════════════════════════════╗\n");
  Print(L"║   DEBUG: CONFIGURATION TABLES             ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");
  Print(L"\n");
  Print(L"Number of Configuration Tables: %lu\n\n", gST->NumberOfTableEntries);
  
  for (UINTN i = 0; i < gST->NumberOfTableEntries; i++) {
    EFI_CONFIGURATION_TABLE *Table = &gST->ConfigurationTable[i];
    
    Print(L"[%lu] GUID: %08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x\n",
          i,
          Table->VendorGuid.Data1,
          Table->VendorGuid.Data2,
          Table->VendorGuid.Data3,
          Table->VendorGuid.Data4[0],
          Table->VendorGuid.Data4[1],
          Table->VendorGuid.Data4[2],
          Table->VendorGuid.Data4[3],
          Table->VendorGuid.Data4[4],
          Table->VendorGuid.Data4[5],
          Table->VendorGuid.Data4[6],
          Table->VendorGuid.Data4[7]);
    Print(L"    Table Address: %p\n", Table->VendorTable);
    
    // Try to identify known tables
    EFI_GUID AcpiTableGuid = { 0xeb9d2d30, 0x2d88, 0x11d3, { 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d }};
    EFI_GUID Acpi20TableGuid = { 0x8868e871, 0xe4f1, 0x11d3, { 0xbc, 0x22, 0x00, 0x80, 0xc7, 0x3c, 0x88, 0x81 }};
    EFI_GUID SmbiosTableGuid = { 0xeb9d2d31, 0x2d88, 0x11d3, { 0x9a, 0x16, 0x00, 0x90, 0x27, 0x3f, 0xc1, 0x4d }};
    EFI_GUID Smbios3TableGuid = { 0xf2fd1544, 0x9794, 0x4a2c, { 0x99, 0x2e, 0xe5, 0xbb, 0xcf, 0x20, 0xe3, 0x94 }};
    
    if (CompareGuid(&Table->VendorGuid, &AcpiTableGuid)) {
      Print(L"    Type: ACPI 1.0 Table\n");
    } else if (CompareGuid(&Table->VendorGuid, &Acpi20TableGuid)) {
      Print(L"    Type: ACPI 2.0+ Table\n");
    } else if (CompareGuid(&Table->VendorGuid, &SmbiosTableGuid)) {
      Print(L"    Type: SMBIOS 2.x Table\n");
    } else if (CompareGuid(&Table->VendorGuid, &Smbios3TableGuid)) {
      Print(L"    Type: SMBIOS 3.x Table\n");
    } else {
      Print(L"    Type: Unknown/Vendor-Specific\n");
    }
    
    Print(L"\n");
  }
  
  Print(L"✓ Configuration table enumeration complete.\n");
}

/**
  Display detailed memory map with all regions
**/
VOID
ShowDetailedMemoryMap(VOID)
{
  EFI_STATUS Status;
  UINTN MemMapSize = 0;
  EFI_MEMORY_DESCRIPTOR *MemMap = NULL;
  UINTN MapKey;
  UINTN DescriptorSize;
  UINT32 DescriptorVersion;
  
  Print(L"\n");
  Print(L"╔════════════════════════════════════════════╗\n");
  Print(L"║   DEBUG: DETAILED MEMORY MAP              ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");
  Print(L"\n");
  
  // Get memory map size
  Status = gBS->GetMemoryMap(&MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
  if (Status == EFI_BUFFER_TOO_SMALL) {
    MemMapSize += 2 * DescriptorSize;
    MemMap = AllocatePool(MemMapSize);
    if (MemMap != NULL) {
      Status = gBS->GetMemoryMap(&MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
      if (!EFI_ERROR(Status)) {
        UINTN EntryCount = MemMapSize / DescriptorSize;
        
        Print(L"Memory Map Entries: %lu\n", EntryCount);
        Print(L"Descriptor Version: 0x%x\n", DescriptorVersion);
        Print(L"Descriptor Size: %lu bytes\n\n", DescriptorSize);
        
        Print(L"Type                      PhysicalStart       VirtualStart        Pages       Attributes\n");
        Print(L"═════════════════════════════════════════════════════════════════════════════════════════\n");
        
        for (UINTN i = 0; i < EntryCount; i++) {
          EFI_MEMORY_DESCRIPTOR *Entry = (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)MemMap + (i * DescriptorSize));
          
          CHAR16 *TypeStr;
          switch (Entry->Type) {
            case EfiReservedMemoryType: TypeStr = L"Reserved"; break;
            case EfiLoaderCode: TypeStr = L"LoaderCode"; break;
            case EfiLoaderData: TypeStr = L"LoaderData"; break;
            case EfiBootServicesCode: TypeStr = L"BSCode"; break;
            case EfiBootServicesData: TypeStr = L"BSData"; break;
            case EfiRuntimeServicesCode: TypeStr = L"RTCode"; break;
            case EfiRuntimeServicesData: TypeStr = L"RTData"; break;
            case EfiConventionalMemory: TypeStr = L"Conventional"; break;
            case EfiUnusableMemory: TypeStr = L"Unusable"; break;
            case EfiACPIReclaimMemory: TypeStr = L"ACPIReclaim"; break;
            case EfiACPIMemoryNVS: TypeStr = L"ACPINVS"; break;
            case EfiMemoryMappedIO: TypeStr = L"MMIO"; break;
            case EfiMemoryMappedIOPortSpace: TypeStr = L"MMIOPort"; break;
            case EfiPalCode: TypeStr = L"PalCode"; break;
            case EfiPersistentMemory: TypeStr = L"Persistent"; break;
            default: TypeStr = L"Unknown"; break;
          }
          
          Print(L"%-20s %016lx %016lx %8lu %016lx\n",
                TypeStr,
                Entry->PhysicalStart,
                Entry->VirtualStart,
                Entry->NumberOfPages,
                Entry->Attribute);
          
          // Pause every 20 entries
          if ((i + 1) % 20 == 0 && (i + 1) < EntryCount) {
            Print(L"\n--- Showing %lu of %lu entries. Press any key to continue (Q to quit)... ---\n\n", i + 1, EntryCount);
            EFI_INPUT_KEY Key;
            UINTN Index;
            gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
            gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
            if (Key.UnicodeChar == L'q' || Key.UnicodeChar == L'Q') {
              Print(L"Memory map display cancelled by user.\n");
              break;
            }
          }
        }
        
        Print(L"\n✓ Memory map enumeration complete.\n");
      }
      FreePool(MemMap);
    }
  }
}

/**
  Show comprehensive debug menu with all diagnostic options
**/
VOID
ShowDebugMenu(VOID)
{
  EFI_INPUT_KEY Key;
  UINTN Index;
  BOOLEAN exitMenu = FALSE;
  
  while (!exitMenu) {
    Print(L"\n");
    Print(L"╔════════════════════════════════════════════╗\n");
    Print(L"║    🔍 DEBUG DIAGNOSTICS MENU 🔍          ║\n");
    Print(L"║  EVERYTHING - ALL VARS, ALL LOGS, ALL!    ║\n");
    Print(L"╚════════════════════════════════════════════╝\n");
    Print(L"\n");
    Print(L"⚠ WARNING: Debug output is extremely verbose!\n");
    Print(L"   These dumps may take several minutes.\n");
    Print(L"\n");
    Print(L"1. Complete Variable Dump (ALL variable data in hex)\n");
    Print(L"2. Protocol Database (Find ALL protocols/IOCTLs)\n");
    Print(L"3. Configuration Tables (ACPI, SMBIOS, etc.)\n");
    Print(L"4. Detailed Memory Map (ALL memory regions)\n");
    Print(L"5. Full System Dump (ALL of the above)\n");
    Print(L"Q. Return to Main Menu\n");
    Print(L"\nSelect option: ");
    
    gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
    gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
    Print(L"%c\n", Key.UnicodeChar);
    
    switch (Key.UnicodeChar) {
      case L'1':
        ShowDebugVariableDump();
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'2':
        ShowProtocolDatabase();
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'3':
        ShowConfigurationTables();
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'4':
        ShowDetailedMemoryMap();
        Print(L"\nPress any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
        
      case L'5':
        Print(L"\n🔥 FULL SYSTEM DUMP - This will take several minutes! 🔥\n");
        Print(L"Press 'Y' to confirm, any other key to cancel: ");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        Print(L"%c\n", Key.UnicodeChar);
        
        if (Key.UnicodeChar == L'Y' || Key.UnicodeChar == L'y') {
          Print(L"\nStarting full system dump...\n");
          ShowDebugVariableDump();
          ShowProtocolDatabase();
          ShowConfigurationTables();
          ShowDetailedMemoryMap();
          Print(L"\n✓ Full system dump complete!\n");
        } else {
          Print(L"Cancelled.\n");
        }
        
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
  Print(L"║  Universal UEFI Diagnostic Tool           ║\n");
  Print(L"║  Full BIOS + Debug Everything Mode        ║\n");
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
  Print(L"  D - 🔍 Debug Diagnostics (EVERYTHING - ALL vars, logs, protocols!)\n");
  Print(L"  N - ☢ Nuclear Wipe Menu (EXTREME)\n");
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
      Print(L"\nOptions: M - Menu, R - Report, D - Debug, N - Nuclear Wipe, Q - Quit\nSelect: ");
    } else if (Key.UnicodeChar == L'R' || Key.UnicodeChar == L'r') {
      DisplaySecurityReport();
      Print(L"\nOptions: M - Menu, R - Report, D - Debug, N - Nuclear Wipe, Q - Quit\nSelect: ");
    } else if (Key.UnicodeChar == L'D' || Key.UnicodeChar == L'd') {
      ShowDebugMenu();
      Print(L"\nOptions: M - Menu, R - Report, D - Debug, N - Nuclear Wipe, Q - Quit\nSelect: ");
    } else if (Key.UnicodeChar == L'N' || Key.UnicodeChar == L'n') {
      ShowNuclearWipeMenu();
      Print(L"\nOptions: M - Menu, R - Report, D - Debug, N - Nuclear Wipe, Q - Quit\nSelect: ");
    } else if (Key.UnicodeChar == L'Q' || Key.UnicodeChar == L'q') {
      break;
    } else {
      Print(L"Invalid option. Try M, R, D, N, or Q: ");
    }
  }

  Print(L"\nReturning to firmware...\n");
  
  // Cleanup
  if (gVariables != NULL) {
    FreePool(gVariables);
  }

  return EFI_SUCCESS;
}
