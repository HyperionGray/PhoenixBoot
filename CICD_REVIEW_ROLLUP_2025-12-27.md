# CI/CD Review Rollup - Comprehensive Analysis

**Date:** 2025-12-27  
**Review Type:** CI/CD Workflow Architecture Review  
**Status:** ✅ COMPLETED

## Executive Summary

This document provides a comprehensive rollup review of the PhoenixBoot CI/CD infrastructure following the Amazon Q Code Review workflow. The analysis covers all 30 GitHub Actions workflows organized into 8 categories, identifying strengths, optimization opportunities, and recommendations for improved automation.

## Review Context

- **Triggered by:** Amazon Q Code Review - 2025-12-25
- **Repository:** P4X-ng/PhoenixBoot
- **Branch:** main
- **Total Workflows:** 30
- **Integration:** Follows previous security reviews (SECURITY_REVIEW_2025-12-07.md, AMAZON_Q_REVIEW_2025-12-22.md)

## Workflow Inventory

### 📊 CI/CD Pipeline Overview

| Category | Count | Purpose | Status |
|----------|-------|---------|--------|
| **Build** | 2 | Platform and artifact builds | ✅ Active |
| **Testing** | 5 | End-to-end and Playwright tests | ✅ Active |
| **Security** | 2 | CodeQL and security scanning | ✅ Active |
| **Code Review** | 8 | Automated reviews and AI analysis | ✅ Active |
| **Issue Management** | 4 | Issue triage and labeling | ✅ Active |
| **PR Management** | 2 | PR labeling and assignment | ✅ Active |
| **Maintenance** | 3 | Stale cleanup and sync | ✅ Active |
| **Automation** | 2 | Size guard and triggers | ✅ Active |
| **Templates** | 2 | Bug/feature templates | ⚠️ Parse issues |

### Total: 30 workflows

## Category Analysis

### 🔨 Build Workflows (2)

#### 1. Build Platform (`BuildPlatform.yml`)
- **Purpose:** Reusable EDKII platform build workflow
- **Trigger:** `workflow_call` (reusable)
- **Status:** ✅ Well-designed
- **Features:**
  - Configurable Python version, runner type, tool chain
  - Artifact upload support
  - Stuart build system integration
- **Assessment:** Production-ready, follows best practices

#### 2. UPL Build (`upl-build.yml`)
- **Purpose:** Universal Payload (UPL) build automation
- **Trigger:** Push/PR events
- **Status:** ✅ Active
- **Assessment:** Specialized build for UPL targets

**Build Category Score:** ✅ **Excellent** - Well-structured, reusable components

---

### 🧪 Testing Workflows (5)

#### 1. End-to-End Tests (`e2e-tests.yml`)
- **Purpose:** Comprehensive QEMU-based testing
- **Trigger:** Push/PR to main, manual
- **Features:**
  - 8 test jobs (setup, basic, secureboot, strict mode, attestation, UUEFI, cloud-init, summary)
  - QEMU with OVMF firmware
  - Artifact preservation (7 days)
  - JUnit report generation
- **Status:** ✅ Comprehensive
- **Coverage:** SecureBoot, NuclearBoot flow, corruption detection, UUEFI, cloud-init

#### 2-5. Playwright Test Workflows (4 workflows)
- `auto-copilot-playwright-auto-test.yml`: Generate and run tests until passing
- `auto-copilot-test-review-playwright.yml`: Comprehensive test review
- `auto-copilot-org-playwright-loop.yaml`: Org-wide test automation (v1)
- `auto-copilot-org-playwright-loopv2.yaml`: Org-wide test automation (v2)

**Testing Category Score:** ✅ **Excellent** - Comprehensive coverage with modern tools

**Observations:**
- ✅ Multiple testing approaches (E2E, Playwright, automated generation)
- ⚠️ Two versions of org-wide Playwright loop (v1 and v2) - consider deprecating v1
- ✅ Good artifact preservation and reporting

---

### 🔒 Security Workflows (2)

#### 1. CodeQL (`codeql.yml`)
- **Purpose:** Static security analysis
- **Trigger:** Push/PR to main
- **Language:** C/C++ (EDKII packages)
- **Runner:** Windows 2022 (toolchain requirement)
- **Packages Analyzed:** 20+ EDK2 packages (CryptoPkg, FatPkg, MdeModulePkg, etc.)
- **Status:** ✅ Comprehensive
- **Integration:** Results upload to GitHub Security

#### 2. Security Scan on PR (`auto-sec-scan.yml`)
- **Purpose:** PR-triggered security scanning
- **Trigger:** Pull request events
- **Status:** ✅ Active
- **Integration:** Complements CodeQL

**Security Category Score:** ✅ **Strong** - Multi-layered security scanning

**Observations:**
- ✅ CodeQL covers 20+ EDK2 packages
- ✅ Dual security scanning (CodeQL + PR scan)
- ✅ Integration with GitHub Security features
- 💡 Recommendation: Add Python CodeQL analysis for scripts

---

### 🔍 Code Review Workflows (8)

This is the **largest category**, showing strong investment in automated code quality.

#### Core Review Workflows

1. **Complete CI/CD Agent Review Pipeline** (`auto-complete-cicd-review.yml`)
   - Trigger: Scheduled (twice daily: 0:00, 12:00 UTC) + manual
   - Purpose: Comprehensive CI/CD review orchestration
   - Status: ✅ Active

2. **Periodic Code Cleanliness Review** (`auto-copilot-code-cleanliness-review.yml`)
   - Trigger: Scheduled (twice daily: 0:00, 12:00 UTC)
   - Purpose: Code quality and organization
   - Status: ✅ Active

3. **Code Functionality and Documentation Review** (`auto-copilot-functionality-docs-review.yml`)
   - Trigger: Manual + automated
   - Purpose: Function correctness and doc quality
   - Status: ✅ Active

4. **AmazonQ Review after GitHub Copilot** (`auto-amazonq-review.yml`)
   - Trigger: After Copilot workflows complete
   - Purpose: Additional AI-powered review layer
   - Status: ✅ Active
   - Integration: Complements GitHub Copilot reviews

#### Assignment and Integration

5. **Auto Assign Copilot to Issues** (`auto-assign-copilot.yml`)
   - Trigger: Issue opened/labeled
   - Purpose: Automated agent assignment
   - Status: ✅ Active

6. **Auto Assign Copilot to PRs** (`auto-assign-pr.yml`)
   - Trigger: PR opened
   - Purpose: Automated PR assignment
   - Status: ✅ Active

7. **Add Pull Request Reviewers** (`request-reviews.yml`)
   - Trigger: PR opened
   - Purpose: Reviewer assignment
   - Status: ✅ Active

#### Advanced Analysis

8. **GPT-5 Implementation Action** (`auto-gpt5-implementation.yml`)
   - Trigger: Issue/PR events
   - Purpose: Advanced AI implementation assistance
   - Status: ✅ Active

**Code Review Category Score:** ✅ **Exceptional** - Multi-layer AI-powered review

**Observations:**
- ✅ Excellent automation coverage
- ✅ Multiple AI review layers (Copilot, Amazon Q, GPT-5)
- ✅ Scheduled reviews ensure continuous quality
- 💡 Twice-daily scheduling is appropriate for active development
- ⚠️ Monitor for potential review fatigue or noise

---

### 📋 Issue Management Workflows (4)

1. **Issue Triage Workflow** (`issue-triage.yml`)
   - Purpose: Automated issue categorization
   - Status: ✅ Active

2. **Auto Label New Issues** (`auto-label.yml`)
   - Trigger: Issue opened
   - Purpose: Automatic label application
   - Status: ✅ Active

3. **React to Issue Assignment** (`issue-assignment.yml`)
   - Trigger: Issue assigned
   - Purpose: Assignment notifications and actions
   - Status: ✅ Active

4. **Close Stale Issues and PRs** (`auto-close-issues.yml`)
   - Trigger: Weekly (Sunday 00:00 UTC)
   - Purpose: Cleanup stale items
   - Status: ✅ Active

**Issue Management Score:** ✅ **Good** - Solid automation coverage

**Observations:**
- ✅ Good coverage of issue lifecycle
- ✅ Automated triage reduces manual overhead
- 💡 Consider adding issue metrics/reporting

---

### 🔄 PR Management Workflows (2)

1. **Apply Labels Based on Message Content** (`pr-labeler.yml`)
   - Trigger: PR opened/edited
   - Purpose: Content-based labeling
   - Status: ✅ Active

2. **Label PRs and Auto-comment** (`auto-label-comment-prs.yml`)
   - Trigger: PR events
   - Purpose: Enhanced PR labeling with comments
   - Status: ✅ Active

**PR Management Score:** ✅ **Good** - Adequate automation

**Observations:**
- ✅ Automated labeling reduces manual work
- 💡 Consider adding PR size limits or complexity analysis

---

### 🔧 Maintenance Workflows (3)

1. **Scheduled Maintenance** (`scheduled-maintenance.yml`)
   - Trigger: Hourly
   - Purpose: Regular maintenance tasks
   - Status: ✅ Active
   - **Note:** Hourly execution - ensure efficiency

2. **Stale Check** (`stale.yml`)
   - Trigger: Daily (23:35 UTC)
   - Purpose: Identify stale issues/PRs
   - Status: ✅ Active

3. **Workflows Sync** (`workflows-sync-template-backup.yml`)
   - Trigger: Daily (6:00 UTC) + manual
   - Purpose: Workflow template synchronization
   - Status: ✅ Active
   - **Feature:** Backup and sync functionality

**Maintenance Score:** ✅ **Good** - Regular automated upkeep

**Observations:**
- ⚠️ Hourly scheduled maintenance may be excessive - consider reducing frequency
- ✅ Daily stale checks appropriate
- ✅ Workflow sync ensures consistency
- 💡 Monitor resource usage of hourly job

---

### ⚙️ Automation Workflows (2)

1. **size-guard** (`size-guard.yml`)
   - Purpose: Monitor and guard against repository size bloat
   - Status: ✅ Active

2. **Trigger Workflow on All Repos** (`trigger-all-repos.yml`)
   - Purpose: Cross-repository workflow orchestration
   - Status: ✅ Active
   - **Note:** Org-wide automation capability

**Automation Score:** ✅ **Good** - Useful utilities

---

### 📝 Template Workflows (2)

1. **Bug Report** (`auto-bug-report.yml`)
   - Status: ⚠️ Parse error (multi-document YAML)
   - Purpose: Bug report template/automation

2. **Feature Request** (`auto-feature-request.yml`)
   - Status: ⚠️ Parse error (multi-document YAML)
   - Purpose: Feature request template/automation

**Template Score:** ⚠️ **Needs Fix** - YAML parsing issues

**Issues:**
- ❌ Multi-document YAML format causing parse errors
- 💡 Recommendation: Restructure to single-document YAML or use GitHub issue forms

---

## 🎯 Key Findings

### ✅ Strengths

1. **Comprehensive Coverage:** 30 workflows covering all aspects of CI/CD
2. **Security Focus:** Strong security scanning with CodeQL and dedicated workflows
3. **AI Integration:** Exceptional use of AI tools (Copilot, Amazon Q, GPT-5)
4. **Testing Excellence:** Multiple testing approaches with good coverage
5. **Automation:** Heavy automation reduces manual overhead
6. **Scheduled Reviews:** Regular quality checks (twice daily) ensure code health
7. **Artifact Preservation:** Good artifact retention policies

### ⚠️ Areas for Improvement

1. **Template Workflows:** Bug/feature request workflows have YAML parsing errors
2. **Workflow Duplication:** Two versions of Playwright org loop (v1 and v2)
3. **Hourly Maintenance:** May be excessive frequency
4. **Python Security:** CodeQL doesn't analyze Python scripts
5. **Documentation:** Workflow relationships could be better documented

### 💡 Optimization Opportunities

1. **Consolidation:** Merge or deprecate duplicate Playwright workflows
2. **Frequency Tuning:** Adjust maintenance schedule from hourly to 2-4 hourly
3. **Caching:** Review and optimize dependency caching across workflows
4. **Parallelization:** Some workflows could benefit from parallel job execution
5. **Resource Monitoring:** Add workflow execution metrics and cost monitoring

---

## 📈 Metrics and Statistics

### Workflow Execution Patterns

| Trigger Type | Count | Purpose |
|--------------|-------|---------|
| `push/pull_request` | ~15 | CI on code changes |
| `workflow_dispatch` | ~10 | Manual triggering |
| `schedule` | 5 | Periodic automation |
| `workflow_call` | 2 | Reusable workflows |
| `issues/pr events` | ~10 | Event-driven automation |

### Scheduling Analysis

| Schedule | Workflow | Frequency | Assessment |
|----------|----------|-----------|------------|
| Twice daily (0:00, 12:00) | CI/CD Review, Code Cleanliness | 2x/day | ✅ Appropriate |
| Hourly | Scheduled Maintenance | 24x/day | ⚠️ Consider reducing |
| Daily (6:00) | Workflows Sync | 1x/day | ✅ Good |
| Daily (23:35) | Stale Check | 1x/day | ✅ Good |
| Weekly (Sunday) | Close Stale | 1x/week | ✅ Good |

### Resource Efficiency

- **Well-utilized:** Build, testing, security workflows
- **High-value automation:** Code review and issue management
- **Potential optimization:** Hourly maintenance could be reduced
- **Artifact storage:** 7-day retention is appropriate

---

## 🔐 Security Assessment

### Current State: ✅ **Strong**

1. **Static Analysis:** CodeQL covering 20+ C/C++ packages
2. **PR Security:** Automated security scanning on PRs
3. **Dependency Scanning:** Integrated with GitHub Security features
4. **Workflow Permissions:** Need to verify all workflows use minimal permissions

### Recommendations

1. **Add Python CodeQL Analysis**
   ```yaml
   # Add to codeql.yml
   - language: python
     paths:
       - 'scripts/**'
       - 'utils/**'
       - '*.py'
   ```

2. **Implement Secrets Scanning**
   - Consider adding git-secrets or TruffleHog to pre-commit
   - Add secrets scanning to CI pipeline

3. **Review Workflow Permissions**
   - Audit all workflows for minimal permission principle
   - Example from e2e-tests.yml (good practice):
     ```yaml
     permissions:
       contents: read
     ```

4. **Supply Chain Security**
   - Pin action versions to SHA (not tags)
   - Enable Dependabot for GitHub Actions
   - Example:
     ```yaml
     # Instead of:
     uses: actions/checkout@v6
     # Use:
     uses: actions/checkout@<SHA>
     ```

---

## 🚀 Performance Optimization

### Current Performance: ✅ **Good**

### Recommendations

1. **Workflow Caching**
   - Verify Python pip cache is used everywhere:
     ```yaml
     - uses: actions/setup-python@v6
       with:
         cache: 'pip'
     ```
   - Add apt cache for system dependencies
   - Cache build artifacts between jobs

2. **Parallel Execution**
   - E2E tests already run in parallel ✅
   - Consider parallelizing CodeQL package analysis

3. **Conditional Execution**
   - Add path filters to avoid unnecessary runs:
     ```yaml
     on:
       push:
         paths-ignore:
           - '**.md'
           - 'docs/**'
     ```

4. **Resource Allocation**
   - Use appropriate runner sizes
   - Consider self-hosted runners for heavy builds

---

## 🏗️ Architecture Assessment

### Current Architecture: ✅ **Well-Designed**

### Strengths

1. **Layered Approach:** Multiple review layers (Copilot → Amazon Q)
2. **Separation of Concerns:** Clear categories with focused workflows
3. **Reusability:** BuildPlatform.yml as reusable workflow
4. **Event-Driven:** Appropriate use of GitHub events

### Recommendations

1. **Workflow Orchestration**
   - Document workflow dependencies
   - Consider creating a workflow diagram
   - Add workflow execution order documentation

2. **Standardization**
   - Create workflow templates for common patterns
   - Standardize job naming conventions
   - Consistent use of permissions blocks

3. **Observability**
   - Add workflow execution metrics
   - Consider GitHub Actions dashboards
   - Track workflow duration and success rates

---

## 🔄 Integration with Previous Reviews

### Builds Upon

1. **SECURITY_REVIEW_2025-12-07.md**
   - ✅ Security scanning workflows implemented
   - ✅ Dependency vulnerability checks active
   - ✅ CodeQL integration complete

2. **AMAZON_Q_REVIEW_2025-12-22.md**
   - ✅ CI/CD review pipeline operational
   - ✅ Amazon Q integration active
   - ✅ Automated review workflows functioning

### New Findings

1. **Template Workflow Issues:** YAML parsing errors need fixing
2. **Workflow Duplication:** Two Playwright loop versions exist
3. **Python Security Gap:** CodeQL doesn't cover Python files
4. **Maintenance Frequency:** Hourly schedule may be excessive

---

## 📋 Action Items

### 🔴 High Priority (Immediate)

- [ ] **Fix template workflow YAML parsing errors**
  - Files: `auto-bug-report.yml`, `auto-feature-request.yml`
  - Issue: Multi-document YAML format
  - Solution: Convert to single-document or use GitHub issue forms

- [ ] **Add Python to CodeQL analysis**
  - Update: `codeql.yml`
  - Add Python language support
  - Cover: `scripts/`, `utils/`, root `*.py`

- [ ] **Audit workflow permissions**
  - Review all 30 workflows
  - Ensure minimal permission principle
  - Add explicit `permissions:` blocks

### 🟡 Medium Priority (1-2 weeks)

- [ ] **Deprecate duplicate Playwright workflow**
  - Decide: Keep v1 or v2 of org-wide loop
  - Document: Migration path if needed
  - Remove: Unused version

- [ ] **Optimize maintenance schedule**
  - Review: Hourly maintenance necessity
  - Adjust: To 2-4 hour intervals if appropriate
  - Monitor: Resource usage impact

- [ ] **Add workflow documentation**
  - Create: CI/CD architecture diagram
  - Document: Workflow dependencies
  - Add: Troubleshooting guide

- [ ] **Implement secrets scanning**
  - Add: Pre-commit hooks
  - Integrate: Into CI pipeline
  - Consider: TruffleHog or git-secrets

### 🟢 Low Priority (1-3 months)

- [ ] **Pin GitHub Actions to SHA**
  - Security: Prevent supply chain attacks
  - Update: All `uses:` statements
  - Enable: Dependabot for Actions

- [ ] **Add workflow metrics**
  - Track: Execution time and success rates
  - Create: Performance dashboard
  - Monitor: Resource consumption

- [ ] **Optimize caching strategy**
  - Review: Current cache usage
  - Add: Additional caching opportunities
  - Measure: Cache hit rates

- [ ] **Create workflow templates**
  - Standardize: Common patterns
  - Document: Best practices
  - Share: Across organization

---

## 📊 Comparison with Industry Best Practices

### ✅ Aligned with Best Practices

1. **Automated Testing:** Comprehensive test coverage ✅
2. **Security Scanning:** Multiple security layers ✅
3. **Code Review:** AI-assisted review automation ✅
4. **Issue Management:** Automated triage and labeling ✅
5. **Artifact Preservation:** Appropriate retention policies ✅

### 💡 Areas to Enhance

1. **Secrets Management:** Add secrets scanning
2. **Supply Chain:** Pin actions to SHA
3. **Monitoring:** Add workflow observability
4. **Documentation:** Improve workflow documentation
5. **Cost Optimization:** Monitor and optimize resource usage

---

## 🎓 Recommendations for Repository Maintainers

### Immediate Actions (This Week)

1. **Fix template workflows** to resolve YAML parsing errors
2. **Add Python CodeQL** support for script security
3. **Audit workflow permissions** for security compliance

### Short-term Improvements (This Month)

1. **Remove duplicate workflows** (Playwright v1 vs v2)
2. **Optimize maintenance schedule** (reduce from hourly)
3. **Document CI/CD architecture** for team understanding
4. **Review and optimize** workflow caching

### Long-term Enhancements (Next Quarter)

1. **Pin Actions to SHA** for supply chain security
2. **Implement secrets scanning** in CI pipeline
3. **Add workflow metrics** and monitoring
4. **Create workflow templates** for consistency
5. **Consider self-hosted runners** for heavy builds

### Monitoring and Maintenance

1. **Weekly:** Review workflow failure rates
2. **Monthly:** Analyze resource usage and costs
3. **Quarterly:** Audit security configurations
4. **Bi-annually:** Review workflow efficiency and consolidation opportunities

---

## 🎯 Success Metrics

To measure CI/CD effectiveness, track:

1. **Reliability**
   - Workflow success rate (target: >95%)
   - Mean time to detect issues (target: <1 hour)
   - False positive rate (target: <5%)

2. **Performance**
   - Average workflow execution time
   - Build time trends
   - Cache hit rates (target: >70%)

3. **Security**
   - Security scan coverage (target: 100%)
   - Vulnerability detection rate
   - Time to fix critical issues (target: <24 hours)

4. **Efficiency**
   - Manual intervention rate (target: <10%)
   - Automation coverage (target: >90%)
   - Resource utilization

---

## 🏆 Overall Assessment

### CI/CD Maturity Level: **Level 4 - Optimizing** (out of 5)

| Category | Score | Notes |
|----------|-------|-------|
| **Build Automation** | 5/5 | Excellent - comprehensive and reusable |
| **Test Automation** | 5/5 | Excellent - E2E and Playwright coverage |
| **Security** | 4/5 | Strong - needs Python CodeQL |
| **Code Review** | 5/5 | Exceptional - multi-layer AI reviews |
| **Issue/PR Management** | 4/5 | Good - solid automation |
| **Maintenance** | 4/5 | Good - needs frequency optimization |
| **Documentation** | 3/5 | Adequate - needs improvement |
| **Monitoring** | 3/5 | Basic - needs metrics/dashboards |

### Overall Score: **4.1/5 - Excellent**

---

## 📝 Conclusion

The PhoenixBoot CI/CD infrastructure represents a **mature, well-designed automation system** with exceptional AI integration and comprehensive coverage. The 30 workflows provide:

- ✅ **Strong security posture** with multi-layer scanning
- ✅ **Comprehensive testing** with E2E and Playwright
- ✅ **Exceptional code review** with AI-powered automation
- ✅ **Solid issue/PR management** reducing manual overhead
- ✅ **Regular maintenance** keeping the repository healthy

### Key Achievements

1. **AI Integration Excellence:** Leading-edge use of Copilot, Amazon Q, and GPT-5
2. **Security-First Approach:** Multiple security scanning layers
3. **Test Coverage:** Comprehensive E2E testing with QEMU
4. **Automation Maturity:** High degree of process automation

### Areas for Improvement

While the system is strong, addressing the identified issues will further enhance:
1. Template workflow YAML errors (high priority)
2. Python security coverage (high priority)
3. Workflow consolidation (medium priority)
4. Documentation and observability (ongoing)

### Final Recommendation

**Status: ✅ PRODUCTION-READY with minor improvements needed**

The CI/CD infrastructure is robust and production-ready. Implementing the high-priority action items will further strengthen security and reliability, while medium and low-priority items will optimize efficiency and maintainability.

---

**Reviewed by:** GitHub Copilot Agent  
**Review Type:** Comprehensive CI/CD Rollup Analysis  
**Date:** 2025-12-27  
**Status:** ✅ COMPLETED  
**Next Review:** Quarterly (April 2026)

---

## Appendix: Workflow Reference

### Complete Workflow List

1. BuildPlatform.yml - Reusable build workflow
2. upl-build.yml - UPL build automation
3. e2e-tests.yml - End-to-end testing
4. auto-copilot-playwright-auto-test.yml - Playwright test generation
5. auto-copilot-test-review-playwright.yml - Test review
6. auto-copilot-org-playwright-loop.yaml - Org-wide test loop v1
7. auto-copilot-org-playwright-loopv2.yaml - Org-wide test loop v2
8. codeql.yml - Security analysis
9. auto-sec-scan.yml - PR security scanning
10. auto-complete-cicd-review.yml - CI/CD review pipeline
11. auto-copilot-code-cleanliness-review.yml - Code quality review
12. auto-copilot-functionality-docs-review.yml - Function/docs review
13. auto-amazonq-review.yml - Amazon Q integration
14. auto-assign-copilot.yml - Issue assignment
15. auto-assign-pr.yml - PR assignment
16. request-reviews.yml - Reviewer assignment
17. auto-gpt5-implementation.yml - GPT-5 assistance
18. issue-triage.yml - Issue triage
19. auto-label.yml - Issue labeling
20. issue-assignment.yml - Assignment reactions
21. auto-close-issues.yml - Stale cleanup
22. pr-labeler.yml - PR labeling
23. auto-label-comment-prs.yml - PR comments
24. scheduled-maintenance.yml - Regular maintenance
25. stale.yml - Stale detection
26. workflows-sync-template-backup.yml - Workflow sync
27. size-guard.yml - Size monitoring
28. trigger-all-repos.yml - Cross-repo triggers
29. auto-bug-report.yml - Bug template (⚠️ needs fix)
30. auto-feature-request.yml - Feature template (⚠️ needs fix)

### Schedule Summary

- **Hourly:** Scheduled maintenance (1 workflow)
- **Twice Daily:** CI/CD review, code cleanliness (2 workflows)
- **Daily:** Workflow sync, stale check (2 workflows)
- **Weekly:** Stale issue closure (1 workflow)
- **Event-driven:** Remaining workflows (~24)
