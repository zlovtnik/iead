# {{title}}

{{description}}

## Deployment Overview

{{overview}}

## Prerequisites

{{#prerequisites}}
### {{category}}

{{#items}}
- {{item}}
{{/items}}

{{/prerequisites}}

## Environment Setup

{{#environments}}
### {{name}}

{{description}}

{{#configuration}}
**Configuration:**

{{#config_files}}
**{{file}}:**
```{{language}}
{{content}}
```

{{/config_files}}

{{#environment_variables}}
**Environment Variables:**

| Variable | Description | Example |
|----------|-------------|---------|
{{#vars}}
| `{{name}}` | {{description}} | `{{example}}` |
{{/vars}}
{{/environment_variables}}

{{/configuration}}

{{/environments}}

## Deployment Procedures

{{#procedures}}
### {{name}}

{{description}}

{{#steps}}
{{step_number}}. {{description}}

{{#command}}
```{{language}}
{{code}}
```
{{/command}}

{{#verification}}
**Verification:**
```{{language}}
{{check}}
```
{{/verification}}

{{#note}}
> **Note:** {{note}}
{{/note}}

{{/steps}}

{{/procedures}}

## Database Migration

{{#migrations}}
### {{version}}

{{description}}

{{#pre_migration}}
**Pre-migration Steps:**
{{#steps}}
{{step_number}}. {{step}}
{{/steps}}
{{/pre_migration}}

**Migration Command:**
```{{language}}
{{command}}
```

{{#post_migration}}
**Post-migration Steps:**
{{#steps}}
{{step_number}}. {{step}}
{{/steps}}
{{/post_migration}}

{{#rollback}}
**Rollback Procedure:**
```{{language}}
{{command}}
```
{{/rollback}}

{{/migrations}}

## Monitoring Setup

{{#monitoring}}
### {{component}}

{{description}}

{{#setup_steps}}
{{step_number}}. {{step}}

{{#config}}
```{{language}}
{{configuration}}
```
{{/config}}

{{/setup_steps}}

{{#metrics}}
**Key Metrics:**
{{#items}}
- {{name}}: {{description}}
{{/items}}
{{/metrics}}

{{#alerts}}
**Alerts:**
{{#items}}
- {{condition}}: {{action}}
{{/items}}
{{/alerts}}

{{/monitoring}}

## Scaling Procedures

{{#scaling}}
### {{type}}

{{description}}

{{#procedures}}
**{{scenario}}:**

{{#steps}}
{{step_number}}. {{step}}

{{#command}}
```{{language}}
{{code}}
```
{{/command}}

{{/steps}}

{{/procedures}}

{{#considerations}}
**Considerations:**
{{#items}}
- {{consideration}}
{{/items}}
{{/considerations}}

{{/scaling}}

## Backup and Recovery

{{#backup}}
### {{type}}

{{description}}

**Backup Command:**
```{{language}}
{{command}}
```

**Recovery Command:**
```{{language}}
{{command}}
```

**Schedule:** {{schedule}}

**Retention:** {{retention}}

{{/backup}}

## Security Considerations

{{#security}}
### {{area}}

{{description}}

{{#measures}}
- {{measure}}
{{/measures}}

{{#checklist}}
**Security Checklist:**
{{#items}}
- [ ] {{item}}
{{/items}}
{{/checklist}}

{{/security}}

## Troubleshooting

{{#troubleshooting}}
### {{issue}}

**Symptoms:**
{{#symptoms}}
- {{symptom}}
{{/symptoms}}

**Diagnosis:**
{{#diagnosis_steps}}
{{step_number}}. {{step}}

{{#command}}
```{{language}}
{{code}}
```
{{/command}}

{{/diagnosis_steps}}

**Resolution:**
{{#resolution_steps}}
{{step_number}}. {{step}}

{{#command}}
```{{language}}
{{code}}
```
{{/command}}

{{/resolution_steps}}

{{/troubleshooting}}

## Rollback Procedures

{{#rollback}}
### {{scenario}}

{{description}}

{{#steps}}
{{step_number}}. {{step}}

{{#command}}
```{{language}}
{{code}}
```
{{/command}}

{{#verification}}
**Verification:**
```{{language}}
{{check}}
```
{{/verification}}

{{/steps}}

{{#time_estimate}}
**Estimated Time:** {{time}}
{{/time_estimate}}

{{/rollback}}