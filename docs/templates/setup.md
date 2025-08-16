# {{title}}

{{description}}

## Prerequisites

{{#prerequisites}}
- {{item}}
{{/prerequisites}}

## Installation

{{#platforms}}
### {{name}}

{{#steps}}
{{step_number}}. {{description}}

{{#code}}
```{{language}}
{{command}}
```
{{/code}}

{{#note}}
> **Note:** {{note}}
{{/note}}

{{/steps}}

{{/platforms}}

## Configuration

{{#config_sections}}
### {{title}}

{{description}}

{{#config_file}}
**File:** `{{path}}`

```{{language}}
{{content}}
```
{{/config_file}}

{{#environment_vars}}
**Environment Variables:**

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
{{#vars}}
| `{{name}}` | {{description}} | {{default}} | {{#required}}Yes{{/required}}{{^required}}No{{/required}} |
{{/vars}}
{{/environment_vars}}

{{/config_sections}}

## Verification

{{#verification_steps}}
{{step_number}}. {{description}}

{{#command}}
```{{language}}
{{code}}
```
{{/command}}

{{#expected_output}}
**Expected Output:**
```
{{output}}
```
{{/expected_output}}

{{/verification_steps}}

## Troubleshooting

{{#troubleshooting}}
### {{problem}}

**Symptoms:**
{{#symptoms}}
- {{symptom}}
{{/symptoms}}

**Solution:**
{{#solutions}}
{{step_number}}. {{step}}

{{#code}}
```{{language}}
{{command}}
```
{{/code}}

{{/solutions}}

{{/troubleshooting}}

## Next Steps

{{#next_steps}}
- [{{title}}]({{url}}) - {{description}}
{{/next_steps}}

## Additional Resources

{{#resources}}
- [{{title}}]({{url}}) - {{description}}
{{/resources}}