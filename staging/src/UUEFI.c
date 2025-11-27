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
#define MAX_DESCRIPTION_SIZE 512
#define MAX_DISPLAYED_DELETIONS 10

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
  - Optionally wipes all non-essential NVRAM variables
  - Provides info about disk wiping tools (nwipe)
  - Resets firmware to defaults
**/
VOID
ShowNuclearWipeMenu(VOID)
{
  EFI_INPUT_KEY Key;
  UINTN Index;
  
  Print(L"\n");
  Print(L"╔════════════════════════════════════════════╗\n");
  Print(L"║      ☢ NUCLEAR WIPE MENU ☢               ║\n");
  Print(L"║  COMPLETE SYSTEM RESET & SANITIZATION     ║\n");
  Print(L"╚════════════════════════════════════════════╝\n");
  Print(L"\n");
  Print(L"⚠⚠⚠ EXTREME WARNING ⚠⚠⚠\n");
  Print(L"This menu provides options for complete system sanitization.\n");
  Print(L"Use these options ONLY when:\n");
  Print(L"  • You have serious malware/rootkit infection\n");
  Print(L"  • You need to completely wipe and reset the system\n");
  Print(L"  • You want to return firmware to factory defaults\n");
  Print(L"\n");
  Print(L"Available Options:\n");
  Print(L"══════════════════\n");
  Print(L"\n");
  Print(L"1. NVRAM Variable Wipe (Vendor Variables Only)\n");
  Print(L"   - Deletes all non-critical vendor-specific variables\n");
  Print(L"   - Preserves boot configuration and security keys\n");
  Print(L"   - Useful for removing vendor bloatware/malware\n");
  Print(L"   ⚠ Risk Level: MEDIUM - May affect vendor features\n");
  Print(L"\n");
  Print(L"2. Full NVRAM Reset (Factory Defaults)\n");
  Print(L"   - Resets ALL variables including boot order\n");
  Print(L"   - Preserves only critical security variables (PK, KEK, db, dbx)\n");
  Print(L"   - System will boot to firmware setup on next boot\n");
  Print(L"   ⚠ Risk Level: HIGH - Will reset all BIOS settings\n");
  Print(L"\n");
  Print(L"3. Disk Wiping Information\n");
  Print(L"   - Shows information about secure disk wiping\n");
  Print(L"   - Recommends nwipe and other tools\n");
  Print(L"   - No data is modified\n");
  Print(L"   ⚠ Risk Level: NONE - Information only\n");
  Print(L"\n");
  Print(L"4. Complete Nuclear Wipe (NVRAM + Disk Instructions)\n");
  Print(L"   - Combination of options 2 & 3\n");
  Print(L"   - Full firmware reset + disk wipe guidance\n");
  Print(L"   - Maximum sanitization for critical situations\n");
  Print(L"   ⚠ Risk Level: EXTREME - Complete system reset\n");
  Print(L"\n");
  Print(L"Q. Return to Main Menu (Recommended)\n");
  Print(L"\n");
  Print(L"Select option (or Q to cancel): ");
  
  gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
  gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
  Print(L"%c\n", Key.UnicodeChar);
  
  switch (Key.UnicodeChar) {
    case L'1':
      // Wipe vendor variables only
      Print(L"\n☢ VENDOR VARIABLE WIPE ☢\n");
      Print(L"═══════════════════════════\n");
      Print(L"This will DELETE all vendor-specific variables that are\n");
      Print(L"marked as safe to remove (excluding critical system variables).\n");
      Print(L"\n");
      Print(L"Variables to be removed: ");
      
      // Count editable vendor variables
      UINTN vendorCount = 0;
      for (UINTN i = 0; i < gVariableCount; i++) {
        if (gVariables[i].Category == VAR_CAT_VENDOR && gVariables[i].IsEditable) {
          vendorCount++;
        }
      }
      Print(L"%lu\n", vendorCount);
      
      if (vendorCount == 0) {
        Print(L"\n✓ No vendor variables found that are safe to remove.\n");
        Print(L"Press any key to continue...");
        gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
        gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
        break;
      }
      
      Print(L"\nType 'WIPE' to confirm (or anything else to cancel): ");
      
      // NOTE: Full string input is complex in UEFI without additional libraries.
      // This implementation checks first character only. For production use,
      // consider implementing full string comparison or using UEFI Forms Browser.
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      Print(L"%c...\n", Key.UnicodeChar);
      
      // Check first character as simplified confirmation
      if (Key.UnicodeChar == L'W' || Key.UnicodeChar == L'w') {
        Print(L"\n⚠ Wiping vendor variables...\n");
        
        UINTN deletedCount = 0;
        for (UINTN i = 0; i < gVariableCount; i++) {
          if (gVariables[i].Category == VAR_CAT_VENDOR && gVariables[i].IsEditable) {
            EFI_STATUS Status = gRT->SetVariable(
              gVariables[i].Name,
              &gVariables[i].VendorGuid,
              0,  // Clear attributes
              0,  // Zero size = delete
              NULL
            );
            
            if (!EFI_ERROR(Status)) {
              deletedCount++;
              Print(L"  ✓ Deleted: %s\n", gVariables[i].Name);
            }
          }
        }
        
        Print(L"\n✓ Deleted %lu vendor variables\n", deletedCount);
        Print(L"  Reboot required for changes to take effect.\n");
      } else {
        Print(L"✗ Cancelled\n");
      }
      
      Print(L"\nPress any key to continue...");
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      break;
      
    case L'2':
      // Full NVRAM reset
      Print(L"\n☢☢☢ FULL NVRAM RESET ☢☢☢\n");
      Print(L"═════════════════════════════\n");
      Print(L"This will DELETE ALL non-security variables!\n");
      Print(L"Your system will:\n");
      Print(L"  • Lose all boot configuration\n");
      Print(L"  • Reset all BIOS settings to defaults\n");
      Print(L"  • Boot to firmware setup on next boot\n");
      Print(L"  • Preserve only Secure Boot keys (PK, KEK, db, dbx)\n");
      Print(L"\n");
      Print(L"This is EXTREME and should ONLY be used if you have\n");
      Print(L"serious firmware malware or corruption.\n");
      Print(L"\n");
      Print(L"Type 'RESET' to confirm (or anything else to cancel): ");
      
      // NOTE: Full string input is complex in UEFI without additional libraries.
      // This implementation checks first character only. For production use,
      // consider implementing full string comparison or using UEFI Forms Browser.
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      Print(L"%c...\n", Key.UnicodeChar);
      
      // Check first character as simplified confirmation
      if (Key.UnicodeChar == L'R' || Key.UnicodeChar == L'r') {
        Print(L"\n⚠⚠⚠ Performing full NVRAM reset...\n");
        
        UINTN resetCount = 0;
        for (UINTN i = 0; i < gVariableCount; i++) {
          // Skip security variables
          if (gVariables[i].Category == VAR_CAT_SECURITY) {
            continue;
          }
          
          EFI_STATUS Status = gRT->SetVariable(
            gVariables[i].Name,
            &gVariables[i].VendorGuid,
            0,
            0,
            NULL
          );
          
          if (!EFI_ERROR(Status)) {
            resetCount++;
            if (resetCount <= MAX_DISPLAYED_DELETIONS) {
              Print(L"  ✓ Deleted: %s\n", gVariables[i].Name);
            } else if (resetCount == MAX_DISPLAYED_DELETIONS + 1) {
              Print(L"  ... (continuing)\n");
            }
          }
        }
        
        Print(L"\n✓ Reset complete: %lu variables deleted\n", resetCount);
        Print(L"  Security keys preserved\n");
        Print(L"  System will boot to firmware setup\n");
        Print(L"  REBOOT IMMEDIATELY\n");
      } else {
        Print(L"✗ Cancelled\n");
      }
      
      Print(L"\nPress any key to continue...");
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      break;
      
    case L'3':
      // Disk wiping information
      Print(L"\n💾 SECURE DISK WIPING INFORMATION 💾\n");
      Print(L"═════════════════════════════════════\n");
      Print(L"\n");
      Print(L"For complete system sanitization, you need to securely\n");
      Print(L"wipe all disk drives in addition to NVRAM reset.\n");
      Print(L"\n");
      Print(L"🔧 Recommended Tool: nwipe\n");
      Print(L"─────────────────────────────────\n");
      Print(L"nwipe is a secure disk eraser that:\n");
      Print(L"  • Supports multiple wipe methods (DoD, Gutmann, PRNG, etc.)\n");
      Print(L"  • Works with HDDs, SSDs, and NVMe drives\n");
      Print(L"  • Provides verification and progress tracking\n");
      Print(L"  • Available on most Linux live systems\n");
      Print(L"\n");
      Print(L"📋 How to use nwipe:\n");
      Print(L"─────────────────────\n");
      Print(L"1. Boot from a Linux live USB (Ubuntu, SystemRescue, etc.)\n");
      Print(L"2. Install nwipe: sudo apt install nwipe\n");
      Print(L"3. Run as root: sudo nwipe\n");
      Print(L"4. Select drives to wipe\n");
      Print(L"5. Choose wipe method (DoD Short is usually sufficient)\n");
      Print(L"6. Start wipe and wait for completion\n");
      Print(L"\n");
      Print(L"⚠ WARNING: This permanently destroys ALL data!\n");
      Print(L"    There is NO RECOVERY after wiping!\n");
      Print(L"\n");
      Print(L"🔐 For SSDs with hardware encryption:\n");
      Print(L"──────────────────────────────────────\n");
      Print(L"  • Use 'hdparm --security-erase' for instant secure erase\n");
      Print(L"  • Or use manufacturer's tools (Samsung Magician, etc.)\n");
      Print(L"  • ATA Secure Erase is faster and more thorough for SSDs\n");
      Print(L"\n");
      Print(L"🔥 Nuclear Option Workflow:\n");
      Print(L"───────────────────────────\n");
      Print(L"1. Use UUEFI option 2 (Full NVRAM Reset) first\n");
      Print(L"2. Reboot to firmware setup\n");
      Print(L"3. Verify all settings reset to defaults\n");
      Print(L"4. Boot to Linux live USB\n");
      Print(L"5. Run nwipe on all drives\n");
      Print(L"6. Reinstall OS from trusted media\n");
      Print(L"7. Re-enroll Secure Boot keys if desired\n");
      Print(L"\n");
      Print(L"Press any key to continue...");
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      break;
      
    case L'4':
      // Complete nuclear wipe
      Print(L"\n☢☢☢ COMPLETE NUCLEAR WIPE ☢☢☢\n");
      Print(L"═════════════════════════════════\n");
      Print(L"This option provides a complete workflow for maximum\n");
      Print(L"system sanitization when dealing with serious malware,\n");
      Print(L"rootkits, or firmware-level infections.\n");
      Print(L"\n");
      Print(L"📋 Nuclear Wipe Procedure:\n");
      Print(L"──────────────────────────\n");
      Print(L"\n");
      Print(L"STEP 1: NVRAM Reset (Done in UUEFI)\n");
      Print(L"  → Use Option 2 to perform Full NVRAM Reset\n");
      Print(L"  → This will happen now if you confirm\n");
      Print(L"\n");
      Print(L"STEP 2: Firmware Reset\n");
      Print(L"  → After NVRAM reset, system will boot to firmware setup\n");
      Print(L"  → Verify all settings are at factory defaults\n");
      Print(L"  → Optionally: Update firmware/BIOS to latest version\n");
      Print(L"\n");
      Print(L"STEP 3: Disk Sanitization (External Tool)\n");
      Print(L"  → Boot Linux live USB (Ubuntu, SystemRescue, etc.)\n");
      Print(L"  → Run: sudo nwipe\n");
      Print(L"  → Select all drives and wipe with DoD method\n");
      Print(L"  → Wait for completion (may take hours)\n");
      Print(L"\n");
      Print(L"STEP 4: Clean Reinstall\n");
      Print(L"  → Install OS from verified trusted media\n");
      Print(L"  → Enable Secure Boot with your own keys\n");
      Print(L"  → Install PhoenixGuard for ongoing protection\n");
      Print(L"\n");
      Print(L"⚠⚠⚠ THIS IS THE NUCLEAR OPTION ⚠⚠⚠\n");
      Print(L"ALL DATA WILL BE PERMANENTLY DESTROYED\n");
      Print(L"ONLY USE IF ABSOLUTELY NECESSARY\n");
      Print(L"\n");
      Print(L"Proceed with NVRAM reset now? (Y/N): ");
      
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      Print(L"%c\n", Key.UnicodeChar);
      
      if (Key.UnicodeChar == L'Y' || Key.UnicodeChar == L'y') {
        Print(L"\n🔥 INITIATING NUCLEAR WIPE SEQUENCE 🔥\n");
        Print(L"\nStep 1/4: NVRAM Reset\n");
        Print(L"═══════════════════════\n");
        
        // Perform the same operation as option 2
        UINTN resetCount = 0;
        for (UINTN i = 0; i < gVariableCount; i++) {
          if (gVariables[i].Category == VAR_CAT_SECURITY) {
            continue;
          }
          
          EFI_STATUS Status = gRT->SetVariable(
            gVariables[i].Name,
            &gVariables[i].VendorGuid,
            0,
            0,
            NULL
          );
          
          if (!EFI_ERROR(Status)) {
            resetCount++;
          }
        }
        
        Print(L"✓ NVRAM reset complete: %lu variables deleted\n", resetCount);
        Print(L"✓ Security keys preserved\n\n");
        Print(L"Next Steps:\n");
        Print(L"──────────\n");
        Print(L"1. System will reboot to firmware setup\n");
        Print(L"2. Verify settings are at defaults\n");
        Print(L"3. Boot Linux live USB\n");
        Print(L"4. Run: sudo nwipe\n");
        Print(L"5. Wipe all drives\n");
        Print(L"6. Reinstall OS from trusted media\n");
        Print(L"\n");
        Print(L"⚠ REBOOT NOW TO COMPLETE THE PROCESS ⚠\n");
      } else {
        Print(L"✗ Nuclear wipe cancelled\n");
      }
      
      Print(L"\nPress any key to continue...");
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      break;
      
    case L'Q':
    case L'q':
      // Return to menu
      break;
      
    default:
      Print(L"Invalid option\n");
      Print(L"Press any key to continue...");
      gBS->WaitForEvent(1, &gST->ConIn->WaitForKey, &Index);
      gST->ConIn->ReadKeyStroke(gST->ConIn, &Key);
      break;
  }
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
    Print(L"8. ☢ Nuclear Wipe Menu (EXTREME)\n");
    Print(L"Q. Return to Firmware\n");
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
        ShowNuclearWipeMenu();
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
  Print(L"║  Universal UEFI Diagnostic Tool           ║\n");
  Print(L"║  Full BIOS Features + Nuclear Wipe        ║\n");
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
      Print(L"\nOptions: M - Menu, R - Report, N - Nuclear Wipe, Q - Quit\nSelect: ");
    } else if (Key.UnicodeChar == L'R' || Key.UnicodeChar == L'r') {
      DisplaySecurityReport();
      Print(L"\nOptions: M - Menu, R - Report, N - Nuclear Wipe, Q - Quit\nSelect: ");
    } else if (Key.UnicodeChar == L'N' || Key.UnicodeChar == L'n') {
      ShowNuclearWipeMenu();
      Print(L"\nOptions: M - Menu, R - Report, N - Nuclear Wipe, Q - Quit\nSelect: ");
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
