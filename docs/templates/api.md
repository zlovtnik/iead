# {{title}}

{{description}}

## Base URL

```
{{base_url}}
```

## Authentication

{{#auth_types}}
### {{name}}

{{description}}

{{#example}}
**Example:**
```{{language}}
{{code}}
```
{{/example}}

{{/auth_types}}

## Endpoints

{{#endpoints}}
### {{method}} {{path}}

{{summary}}

{{#description}}
{{description}}
{{/description}}

{{#auth_required}}
**Authentication Required:** {{auth_required}}
{{/auth_required}}

{{#parameters}}
#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
{{#params}}
| {{name}} | {{type}} | {{#required}}Yes{{/required}}{{^required}}No{{/required}} | {{description}} |
{{/params}}

{{/parameters}}

{{#request_body}}
#### Request Body

{{#schema}}
**Schema:** {{schema}}
{{/schema}}

{{#example}}
**Example:**
```json
{{example}}
```
{{/example}}

{{/request_body}}

#### Responses

{{#responses}}
**{{status_code}}** - {{description}}

{{#schema}}
**Schema:** {{schema}}
{{/schema}}

{{#example}}
**Example:**
```json
{{example}}
```
{{/example}}

{{/responses}}

{{#code_examples}}
#### Code Examples

{{#examples}}
**{{language}}:**
```{{language}}
{{code}}
```

{{/examples}}
{{/code_examples}}

---

{{/endpoints}}

## Data Models

{{#models}}
### {{name}}

{{description}}

{{#properties}}
| Property | Type | Required | Description |
|----------|------|----------|-------------|
{{#props}}
| {{name}} | {{type}} | {{#required}}Yes{{/required}}{{^required}}No{{/required}} | {{description}} |
{{/props}}
{{/properties}}

{{#example}}
**Example:**
```json
{{example}}
```
{{/example}}

{{/models}}

## Error Handling

{{#error_codes}}
### {{code}} - {{title}}

{{description}}

{{#example}}
**Example Response:**
```json
{{example}}
```
{{/example}}

{{/error_codes}}

## Rate Limiting

{{rate_limit_description}}

{{#rate_limits}}
- **{{endpoint}}**: {{limit}} requests per {{window}}
{{/rate_limits}}

## Changelog

{{#changelog}}
### Version {{version}} - {{date}}

{{#changes}}
- {{type}}: {{description}}
{{/changes}}

{{/changelog}}