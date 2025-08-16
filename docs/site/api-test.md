# Test API Documentation

This is a test of the template processing system

## Base URL

```
http://localhost:8080
```

## Authentication

{{#auth_types}}
### {{name}}

This is a test of the template processing system

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
This is a test of the template processing system
{{/description}}

{{#auth_required}}
**Authentication Required:** {{auth_required}}
{{/auth_required}}

{{#parameters}}
#### Parameters

| Name | Type | Required | Description |
|------|------|----------|-------------|
{{#params}}
| {{name}} | {{type}} | {{#required}}Yes{{/required}}{{^required}}No{{/required}} | This is a test of the template processing system |
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
**{{status_code}}** - This is a test of the template processing system

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

This is a test of the template processing system

{{#properties}}
| Property | Type | Required | Description |
|----------|------|----------|-------------|
{{#props}}
| {{name}} | {{type}} | {{#required}}Yes{{/required}}{{^required}}No{{/required}} | This is a test of the template processing system |
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
### {{code}} - Test API Documentation

This is a test of the template processing system

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
### Version 1.0.0 - {{date}}

{{#changes}}
- {{type}}: This is a test of the template processing system
{{/changes}}

{{/changelog}}