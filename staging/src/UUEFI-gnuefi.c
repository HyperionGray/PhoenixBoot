/*
 * UUEFI - Universal UEFI Diagnostic Application (GNU-EFI version)
 * 
 * Enhanced with variable management and security analysis capabilities.
 * Displays system information and provides interactive diagnostics.
 */

#include <efi.h>
#include <efilib.h>

#define UUEFI_VERSION L"3.1.0-gnuefi"
#define MAX_BOOT_ENTRIES 10
#define MAX_VARIABLE_NAME_SIZE 1024
#define MAX_VARIABLES 500

// Variable categories
typedef enum {
  VAR_CAT_BOOT,
  VAR_CAT_SECURITY,
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
} VARIABLE_INFO;

// Global state
STATIC VARIABLE_INFO *gVariables = NULL;
STATIC UINTN gVariableCount = 0;
STATIC UINTN gSuspiciousCount = 0;

/**
  Compare two GUIDs
**/
BOOLEAN
CompareGuid(EFI_GUID *Guid1, EFI_GUID *Guid2)
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
  Categorize a variable
**/
VARIABLE_CATEGORY
CategorizeVariable(CHAR16 *Name, EFI_GUID *Guid)
{
    if (CompareGuid(Guid, &gEfiGlobalVariableGuid)) {
        if (StrnCmp(Name, L"Boot", 4) == 0 || 
            StriCmp(Name, L"BootOrder") == 0) {
            return VAR_CAT_BOOT;
        }
        if (StriCmp(Name, L"SecureBoot") == 0 ||
            StriCmp(Name, L"PK") == 0 ||
            StriCmp(Name, L"KEK") == 0 ||
            StriCmp(Name, L"db") == 0 ||
            StriCmp(Name, L"dbx") == 0) {
            return VAR_CAT_SECURITY;
        }
    }
    return VAR_CAT_VENDOR;
}

/**
  Check for suspicious patterns
**/
VOID
CheckVariableHeuristics(VARIABLE_INFO *var)
{
    var->IsSuspicious = FALSE;
    
    // Large variables (except db/dbx)
    if (var->DataSize > 32768 && 
        StriCmp(var->Name, L"db") != 0 && 
        StriCmp(var->Name, L"dbx") != 0) {
        var->IsSuspicious = TRUE;
        gSuspiciousCount++;
    }
    
    // Suspicious keywords in vendor variables
    if (var->Category == VAR_CAT_VENDOR) {
        if (StrStr(var->Name, L"Debug") || 
            StrStr(var->Name, L"Test") ||
            StrStr(var->Name, L"Backdoor")) {
            var->IsSuspicious = TRUE;
            gSuspiciousCount++;
        }
    }
}

/**
  Enumerate all EFI variables
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
    
    gVariables = AllocateZeroPool(MAX_VARIABLES * sizeof(VARIABLE_INFO));
    if (!gVariables) {
        Print(L"Failed to allocate memory\n");
        return EFI_OUT_OF_RESOURCES;
    }
    
    gVariableCount = 0;
    gSuspiciousCount = 0;
    
    VariableName[0] = 0;
    NameSize = sizeof(VariableName);
    
    while (TRUE) {
        Status = uefi_call_wrapper(RT->GetNextVariableName, 3,
                                   &NameSize, VariableName, &VendorGuid);
        
        if (EFI_ERROR(Status)) {
            if (Status == EFI_NOT_FOUND) {
                break;
            }
            if (Status == EFI_BUFFER_TOO_SMALL) {
                NameSize = sizeof(VariableName);
                continue;
            }
            break;
        }
        
        if (gVariableCount >= MAX_VARIABLES) {
            Print(L"Warning: Maximum variable count reached\n");
            break;
        }
        
        DataSize = 0;
        Status = uefi_call_wrapper(RT->GetVariable, 5,
                                   VariableName, &VendorGuid, 
                                   &Attributes, &DataSize, NULL);
        
        if (Status == EFI_BUFFER_TOO_SMALL || Status == EFI_SUCCESS) {
            VARIABLE_INFO *var = &gVariables[gVariableCount];
            
            // Safely copy variable name with bounds check
            UINTN nameLen = StrLen(VariableName);
            if (nameLen >= MAX_VARIABLE_NAME_SIZE) {
                nameLen = MAX_VARIABLE_NAME_SIZE - 1;
            }
            CopyMem(var->Name, VariableName, nameLen * sizeof(CHAR16));
            var->Name[nameLen] = 0;  // Null terminate
            
            CopyMem(&var->VendorGuid, &VendorGuid, sizeof(EFI_GUID));
            var->DataSize = DataSize;
            var->Attributes = Attributes;
            var->Category = CategorizeVariable(VariableName, &VendorGuid);
            
            CheckVariableHeuristics(var);
            
            gVariableCount++;
        }
        
        NameSize = sizeof(VariableName);
    }
    
    Print(L"Found %lu EFI variables\n", gVariableCount);
    Print(L"Suspicious items detected: %lu\n", gSuspiciousCount);
    
    return EFI_SUCCESS;
}

/**
  Display variables by category
**/
VOID
DisplayVariablesByCategory(INTN Category)
{
    CHAR16 *CategoryNames[] = {
        L"Boot Configuration",
        L"Security",
        L"Vendor-Specific",
        L"Unknown"
    };
    
    for (UINTN cat = 0; cat < 4; cat++) {
        if (Category >= 0 && (UINTN)Category != cat) {
            continue;
        }
        
        UINTN count = 0;
        for (UINTN i = 0; i < gVariableCount; i++) {
            if (gVariables[i].Category == cat) {
                count++;
            }
        }
        
        if (count == 0) continue;
        
        Print(L"\n--- %s (%lu variables) ---\n", CategoryNames[cat], count);
        
        for (UINTN i = 0; i < gVariableCount; i++) {
            if (gVariables[i].Category == cat) {
                Print(L"  %s", gVariables[i].Name);
                if (gVariables[i].IsSuspicious) {
                    Print(L" ⚠ SUSPICIOUS");
                }
                Print(L"\n    Size: %lu bytes\n", gVariables[i].DataSize);
            }
        }
    }
}

/**
  Display security report
**/
VOID
DisplaySecurityReport(VOID)
{
    Print(L"\n");
    Print(L"╔════════════════════════════════════════════╗\n");
    Print(L"║     SECURITY ANALYSIS REPORT              ║\n");
    Print(L"╚════════════════════════════════════════════╝\n");
    Print(L"\nTotal Variables: %lu\n", gVariableCount);
    Print(L"Suspicious Items: %lu\n\n", gSuspiciousCount);
    
    if (gSuspiciousCount == 0) {
        Print(L"✓ No suspicious activity detected\n");
        return;
    }
    
    Print(L"Suspicious Variables:\n");
    for (UINTN i = 0; i < gVariableCount; i++) {
        if (gVariables[i].IsSuspicious) {
            Print(L"  • %s (Size: %lu bytes)\n", 
                  gVariables[i].Name, gVariables[i].DataSize);
        }
    }
}

/**
  Interactive menu
**/
VOID
ShowInteractiveMenu(VOID)
{
    EFI_INPUT_KEY Key;
    UINTN MapKey;
    BOOLEAN exitMenu = FALSE;
    
    while (!exitMenu) {
        Print(L"\n");
        Print(L"╔════════════════════════════════════════════╗\n");
        Print(L"║        UUEFI INTERACTIVE MENU             ║\n");
        Print(L"╚════════════════════════════════════════════╝\n");
        Print(L"\n");
        Print(L"1. View All Variables\n");
        Print(L"2. View Boot Variables\n");
        Print(L"3. View Security Variables\n");
        Print(L"4. View Vendor Variables\n");
        Print(L"5. Show Security Report\n");
        Print(L"6. Re-scan Variables\n");
        Print(L"Q. Return\n");
        Print(L"\nSelect: ");
        
        uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
        uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
        Print(L"%c\n", Key.UnicodeChar);
        
        switch (Key.UnicodeChar) {
            case L'1':
                DisplayVariablesByCategory(-1);
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'2':
                DisplayVariablesByCategory(VAR_CAT_BOOT);
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'3':
                DisplayVariablesByCategory(VAR_CAT_SECURITY);
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'4':
                DisplayVariablesByCategory(VAR_CAT_VENDOR);
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'5':
                DisplaySecurityReport();
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'6':
                if (gVariables) {
                    FreePool(gVariables);
                    gVariables = NULL;
                }
                EnumerateAllVariables();
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'Q':
            case L'q':
                exitMenu = TRUE;
                break;
        }
    }
}

/**
  Dump variable data in hex and ASCII format (GNU-EFI version)
**/
VOID
DumpVariableDataGnuefi(CHAR16 *Name, EFI_GUID *Guid, UINTN DataSize)
{
    EFI_STATUS Status;
    UINT8 *Data = NULL;
    
    if (DataSize == 0) {
        Print(L"    [Empty variable]\n");
        return;
    }
    
    UINTN DisplaySize = DataSize;
    BOOLEAN Truncated = FALSE;
    if (DisplaySize > 256) {
        DisplaySize = 256;
        Truncated = TRUE;
    }
    
    Data = AllocateZeroPool(DataSize);
    if (!Data) {
        Print(L"    [Failed to allocate memory]\n");
        return;
    }
    
    Status = uefi_call_wrapper(RT->GetVariable, 5, Name, Guid, NULL, &DataSize, Data);
    
    if (EFI_ERROR(Status)) {
        Print(L"    [Failed to read: %r]\n", Status);
        FreePool(Data);
        return;
    }
    
    Print(L"    Hex dump (%lu bytes%s):\n", DataSize, Truncated ? L", truncated" : L"");
    for (UINTN i = 0; i < DisplaySize; i += 16) {
        Print(L"    %04x: ", i);
        
        for (UINTN j = 0; j < 16 && (i + j) < DisplaySize; j++) {
            Print(L"%02x ", Data[i + j]);
        }
        
        for (UINTN j = DisplaySize - i; j < 16 && i + j >= DisplaySize; j++) {
            Print(L"   ");
        }
        
        Print(L" |");
        
        for (UINTN j = 0; j < 16 && (i + j) < DisplaySize; j++) {
            UINT8 c = Data[i + j];
            if (c >= 0x20 && c <= 0x7E) {
                Print(L"%c", (CHAR16)c);
            } else {
                Print(L".");
            }
        }
        
        Print(L"|\n");
    }
    
    if (Truncated) {
        Print(L"    ... (%lu more bytes not shown)\n", DataSize - DisplaySize);
    }
    
    FreePool(Data);
}

/**
  Show complete variable dump (GNU-EFI version)
**/
VOID
ShowDebugVariableDumpGnuefi(VOID)
{
    Print(L"\n");
    Print(L"╔════════════════════════════════════════════╗\n");
    Print(L"║    DEBUG: COMPLETE VARIABLE DUMP          ║\n");
    Print(L"╚════════════════════════════════════════════╝\n");
    Print(L"\n");
    Print(L"Dumping ALL %lu variables with full data...\n\n", gVariableCount);
    
    for (UINTN i = 0; i < gVariableCount; i++) {
        VARIABLE_INFO *var = &gVariables[i];
        
        Print(L"[%lu] %s\n", i, var->Name);
        Print(L"  GUID: %08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x\n",
              var->VendorGuid.Data1, var->VendorGuid.Data2, var->VendorGuid.Data3,
              var->VendorGuid.Data4[0], var->VendorGuid.Data4[1],
              var->VendorGuid.Data4[2], var->VendorGuid.Data4[3],
              var->VendorGuid.Data4[4], var->VendorGuid.Data4[5],
              var->VendorGuid.Data4[6], var->VendorGuid.Data4[7]);
        Print(L"  Size: %lu bytes\n", var->DataSize);
        Print(L"  Attributes: 0x%08x\n", var->Attributes);
        
        DumpVariableDataGnuefi(var->Name, &var->VendorGuid, var->DataSize);
        Print(L"\n");
        
        if ((i + 1) % 5 == 0 && (i + 1) < gVariableCount) {
            Print(L"--- Showing %lu of %lu. Press any key (Q to quit)... ---\n", i + 1, gVariableCount);
            EFI_INPUT_KEY Key;
            UINTN MapKey;
            uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
            uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
            if (Key.UnicodeChar == L'q' || Key.UnicodeChar == L'Q') {
                Print(L"Cancelled.\n");
                return;
            }
        }
    }
    
    Print(L"\n✓ Complete variable dump finished.\n");
}

/**
  Show protocol database (GNU-EFI version)
**/
VOID
ShowProtocolDatabaseGnuefi(VOID)
{
    EFI_STATUS Status;
    UINTN HandleCount = 0;
    EFI_HANDLE *HandleBuffer = NULL;
    
    Print(L"\n");
    Print(L"╔════════════════════════════════════════════╗\n");
    Print(L"║   DEBUG: PROTOCOL DATABASE ENUMERATION    ║\n");
    Print(L"╚════════════════════════════════════════════╝\n");
    Print(L"\n");
    
    Status = uefi_call_wrapper(BS->LocateHandleBuffer, 5,
                               AllHandles, NULL, NULL, &HandleCount, &HandleBuffer);
    
    if (EFI_ERROR(Status)) {
        Print(L"Failed to enumerate handles: %r\n", Status);
        return;
    }
    
    Print(L"Found %lu handles in system\n\n", HandleCount);
    
    for (UINTN i = 0; i < HandleCount; i++) {
        EFI_GUID **ProtocolGuidArray = NULL;
        UINTN ProtocolCount = 0;
        
        Status = uefi_call_wrapper(BS->ProtocolsPerHandle, 3,
                                   HandleBuffer[i], &ProtocolGuidArray, &ProtocolCount);
        
        if (!EFI_ERROR(Status) && ProtocolCount > 0) {
            Print(L"Handle[%lu]: %p (%lu protocols)\n", i, HandleBuffer[i], ProtocolCount);
            
            for (UINTN j = 0; j < ProtocolCount; j++) {
                Print(L"  Protocol[%lu]: %08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x\n",
                      j,
                      ProtocolGuidArray[j]->Data1, ProtocolGuidArray[j]->Data2,
                      ProtocolGuidArray[j]->Data3,
                      ProtocolGuidArray[j]->Data4[0], ProtocolGuidArray[j]->Data4[1],
                      ProtocolGuidArray[j]->Data4[2], ProtocolGuidArray[j]->Data4[3],
                      ProtocolGuidArray[j]->Data4[4], ProtocolGuidArray[j]->Data4[5],
                      ProtocolGuidArray[j]->Data4[6], ProtocolGuidArray[j]->Data4[7]);
            }
            
            FreePool(ProtocolGuidArray);
        }
        
        if ((i + 1) % 10 == 0 && (i + 1) < HandleCount) {
            Print(L"\n--- Showing %lu of %lu. Press any key (Q to quit)... ---\n", i + 1, HandleCount);
            EFI_INPUT_KEY Key;
            UINTN MapKey;
            uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
            uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
            if (Key.UnicodeChar == L'q' || Key.UnicodeChar == L'Q') {
                Print(L"Cancelled.\n");
                break;
            }
            Print(L"\n");
        }
    }
    
    FreePool(HandleBuffer);
    Print(L"\n✓ Protocol database enumeration complete.\n");
}

/**
  Show configuration tables (GNU-EFI version)
**/
VOID
ShowConfigurationTablesGnuefi(VOID)
{
    Print(L"\n");
    Print(L"╔════════════════════════════════════════════╗\n");
    Print(L"║   DEBUG: CONFIGURATION TABLES             ║\n");
    Print(L"╚════════════════════════════════════════════╝\n");
    Print(L"\n");
    Print(L"Number of Configuration Tables: %lu\n\n", ST->NumberOfTableEntries);
    
    for (UINTN i = 0; i < ST->NumberOfTableEntries; i++) {
        EFI_CONFIGURATION_TABLE *Table = &ST->ConfigurationTable[i];
        
        Print(L"[%lu] GUID: %08x-%04x-%04x-%02x%02x-%02x%02x%02x%02x%02x%02x\n",
              i,
              Table->VendorGuid.Data1, Table->VendorGuid.Data2,
              Table->VendorGuid.Data3,
              Table->VendorGuid.Data4[0], Table->VendorGuid.Data4[1],
              Table->VendorGuid.Data4[2], Table->VendorGuid.Data4[3],
              Table->VendorGuid.Data4[4], Table->VendorGuid.Data4[5],
              Table->VendorGuid.Data4[6], Table->VendorGuid.Data4[7]);
        Print(L"    Table Address: %p\n\n", Table->VendorTable);
    }
    
    Print(L"✓ Configuration table enumeration complete.\n");
}

/**
  Show debug menu (GNU-EFI version)
**/
VOID
ShowDebugMenuGnuefi(VOID)
{
    EFI_INPUT_KEY Key;
    UINTN MapKey;
    BOOLEAN exitMenu = FALSE;
    
    while (!exitMenu) {
        Print(L"\n");
        Print(L"╔════════════════════════════════════════════╗\n");
        Print(L"║    🔍 DEBUG DIAGNOSTICS MENU 🔍          ║\n");
        Print(L"║  EVERYTHING - ALL VARS, ALL LOGS, ALL!    ║\n");
        Print(L"╚════════════════════════════════════════════╝\n");
        Print(L"\n");
        Print(L"⚠ WARNING: Debug output is extremely verbose!\n");
        Print(L"\n");
        Print(L"1. Complete Variable Dump (ALL variable data)\n");
        Print(L"2. Protocol Database (Find ALL protocols/IOCTLs)\n");
        Print(L"3. Configuration Tables (ACPI, SMBIOS, etc.)\n");
        Print(L"4. Full System Dump (ALL of the above)\n");
        Print(L"Q. Return to Main Menu\n");
        Print(L"\nSelect: ");
        
        uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
        uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
        Print(L"%c\n", Key.UnicodeChar);
        
        switch (Key.UnicodeChar) {
            case L'1':
                ShowDebugVariableDumpGnuefi();
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'2':
                ShowProtocolDatabaseGnuefi();
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'3':
                ShowConfigurationTablesGnuefi();
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                break;
            case L'4':
                Print(L"\n🔥 FULL SYSTEM DUMP 🔥\n");
                Print(L"Press 'Y' to confirm: ");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
                Print(L"%c\n", Key.UnicodeChar);
                
                if (Key.UnicodeChar == L'Y' || Key.UnicodeChar == L'y') {
                    Print(L"\nStarting full system dump...\n");
                    ShowDebugVariableDumpGnuefi();
                    ShowProtocolDatabaseGnuefi();
                    ShowConfigurationTablesGnuefi();
                    Print(L"\n✓ Full system dump complete!\n");
                } else {
                    Print(L"Cancelled.\n");
                }
                
                Print(L"\nPress any key...");
                uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
                uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
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

EFI_STATUS
EFIAPI
efi_main(EFI_HANDLE ImageHandle, EFI_SYSTEM_TABLE *SystemTable)
{
    EFI_STATUS Status;
    EFI_INPUT_KEY Key;
    UINT8 SecureBoot = 0;
    UINT8 SetupMode = 0;
    UINTN Size;
    
    // Initialize gnu-efi library
    InitializeLib(ImageHandle, SystemTable);
    
    // Clear screen
    uefi_call_wrapper(ST->ConOut->ClearScreen, 1, ST->ConOut);
    
    // Display banner
    Print(L"\n");
    Print(L"╔════════════════════════════════════════════╗\n");
    Print(L"║  🔥 PhoenixGuard UUEFI %s    ║\n", UUEFI_VERSION);
    Print(L"║  Universal UEFI Diagnostic Tool           ║\n");
    Print(L"║  Full BIOS + Debug Everything Mode        ║\n");
    Print(L"╚════════════════════════════════════════════╝\n");
    
    // Display marker for test detection
    Print(L"\n[UUEFI-START]\n");
    
    // Firmware Information
    Print(L"\n=== Firmware Information ===\n");
    Print(L"Vendor: %s\n", ST->FirmwareVendor);
    Print(L"Revision: 0x%08x\n", ST->FirmwareRevision);
    Print(L"UEFI Version: %d.%d\n", 
        (ST->Hdr.Revision >> 16) & 0xFFFF,
        ST->Hdr.Revision & 0xFFFF);
    
    // Security Status
    Print(L"\n=== Security Status ===\n");
    
    // Try to get SecureBoot variable
    Size = sizeof(SecureBoot);
    Status = uefi_call_wrapper(RT->GetVariable, 5,
        L"SecureBoot",
        &gEfiGlobalVariableGuid,
        NULL,
        &Size,
        &SecureBoot);
    
    if (EFI_ERROR(Status)) {
        Print(L"Secure Boot: Unknown (cannot read variable)\n");
    } else {
        Print(L"Secure Boot: %s\n", SecureBoot ? L"Enabled" : L"Disabled");
    }
    
    // Try to get SetupMode variable
    Size = sizeof(SetupMode);
    Status = uefi_call_wrapper(RT->GetVariable, 5,
        L"SetupMode",
        &gEfiGlobalVariableGuid,
        NULL,
        &Size,
        &SetupMode);
    
    if (!EFI_ERROR(Status)) {
        Print(L"Setup Mode: %s\n", SetupMode ? L"Yes" : L"No");
    }
    
    // Status interpretation
    if (SecureBoot && !SetupMode) {
        Print(L"Status: ✓ Secure Boot active and configured\n");
    } else if (!SecureBoot) {
        Print(L"Status: ⚠ Secure Boot disabled\n");
    } else if (SetupMode) {
        Print(L"Status: ⚠ In setup mode - keys not enrolled\n");
    }
    
    // Memory Information
    Print(L"\n=== Memory Information ===\n");
    UINTN MemMapSize = 0;
    EFI_MEMORY_DESCRIPTOR *MemMap = NULL;
    UINTN MapKey;
    UINTN DescriptorSize;
    UINT32 DescriptorVersion;
    UINT64 TotalMemory = 0;
    UINT64 AvailableMemory = 0;
    
    // Get memory map size
    Status = uefi_call_wrapper(BS->GetMemoryMap, 5,
        &MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
    
    if (Status == EFI_BUFFER_TOO_SMALL) {
        MemMapSize += 2 * DescriptorSize;
        MemMap = AllocatePool(MemMapSize);
        if (MemMap) {
            Status = uefi_call_wrapper(BS->GetMemoryMap, 5,
                &MemMapSize, MemMap, &MapKey, &DescriptorSize, &DescriptorVersion);
            
            if (!EFI_ERROR(Status)) {
                UINTN EntryCount = MemMapSize / DescriptorSize;
                EFI_MEMORY_DESCRIPTOR *Entry;
                
                for (UINTN i = 0; i < EntryCount; i++) {
                    Entry = (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)MemMap + (i * DescriptorSize));
                    TotalMemory += Entry->NumberOfPages * 4096;
                    
                    if (Entry->Type == EfiConventionalMemory ||
                        Entry->Type == EfiBootServicesData ||
                        Entry->Type == EfiBootServicesCode) {
                        AvailableMemory += Entry->NumberOfPages * 4096;
                    }
                }
                
                Print(L"Total Memory: %lu MB\n", TotalMemory / (1024 * 1024));
                Print(L"Available Memory: %lu MB\n", AvailableMemory / (1024 * 1024));
            }
            FreePool(MemMap);
        }
    }
    
    // Boot Configuration
    Print(L"\n=== Boot Configuration ===\n");
    UINT16 *BootOrder = NULL;
    Size = 0;
    
    Status = uefi_call_wrapper(RT->GetVariable, 5,
        L"BootOrder",
        &gEfiGlobalVariableGuid,
        NULL,
        &Size,
        NULL);
    
    if (Status == EFI_BUFFER_TOO_SMALL) {
        BootOrder = AllocatePool(Size);
        if (BootOrder) {
            Status = uefi_call_wrapper(RT->GetVariable, 5,
                L"BootOrder",
                &gEfiGlobalVariableGuid,
                NULL,
                &Size,
                BootOrder);
            
            if (!EFI_ERROR(Status)) {
                UINTN Count = Size / sizeof(UINT16);
                Print(L"Boot Order: ");
                for (UINTN i = 0; i < Count && i < MAX_BOOT_ENTRIES; i++) {
                    Print(L"%04x ", BootOrder[i]);
                }
                Print(L"\n");
            }
            FreePool(BootOrder);
        }
    }
    
    // NEW: Advanced variable management and security
    Print(L"\n");
    Print(L"═══════════════════════════════════════════════\n");
    Print(L"  ADVANCED: Variable Management & Security\n");
    Print(L"═══════════════════════════════════════════════\n");
    
    EnumerateAllVariables();
    
    if (gSuspiciousCount > 0) {
        Print(L"\n⚠ ALERT: %lu suspicious items detected!\n", gSuspiciousCount);
        Print(L"  Use the interactive menu to view details.\n");
    } else {
        Print(L"\n✓ No suspicious activity detected\n");
    }
    
    // Display completion marker
    Print(L"\n[UUEFI-COMPLETE]\n");
    
    // Interactive options
    Print(L"\n\nOptions:\n");
    Print(L"  M - Enter Interactive Menu\n");
    Print(L"  R - Show Security Report\n");
    Print(L"  D - 🔍 Debug Diagnostics (EVERYTHING!)\n");
    Print(L"  Q - Return to Firmware\n");
    Print(L"\nSelect: ");
    
    while (TRUE) {
        uefi_call_wrapper(BS->WaitForEvent, 3, 1, &ST->ConIn->WaitForKey, &MapKey);
        uefi_call_wrapper(ST->ConIn->ReadKeyStroke, 2, ST->ConIn, &Key);
        Print(L"%c\n", Key.UnicodeChar);
        
        if (Key.UnicodeChar == L'M' || Key.UnicodeChar == L'm') {
            ShowInteractiveMenu();
            Print(L"\nOptions: M - Menu, R - Report, D - Debug, Q - Quit\nSelect: ");
        } else if (Key.UnicodeChar == L'R' || Key.UnicodeChar == L'r') {
            DisplaySecurityReport();
            Print(L"\nOptions: M - Menu, R - Report, D - Debug, Q - Quit\nSelect: ");
        } else if (Key.UnicodeChar == L'D' || Key.UnicodeChar == L'd') {
            ShowDebugMenuGnuefi();
            Print(L"\nOptions: M - Menu, R - Report, D - Debug, Q - Quit\nSelect: ");
        } else if (Key.UnicodeChar == L'Q' || Key.UnicodeChar == L'q') {
            break;
        } else {
            Print(L"Invalid. Try M, R, D, or Q: ");
        }
    }
    
    Print(L"\nReturning to firmware...\n");
    
    // Cleanup
    if (gVariables) {
        FreePool(gVariables);
    }
    
    return EFI_SUCCESS;
}
