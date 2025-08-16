# {{title}}

{{description}}

## System Overview

{{overview}}

{{#architecture_diagram}}
```mermaid
{{diagram}}
```
{{/architecture_diagram}}

## Components

{{#components}}
### {{name}}

**Purpose:** {{purpose}}

**Location:** `{{location}}`

{{#description}}
{{description}}
{{/description}}

{{#responsibilities}}
**Responsibilities:**
{{#items}}
- {{item}}
{{/items}}
{{/responsibilities}}

{{#interfaces}}
**Interfaces:**
{{#items}}
- **{{name}}**: {{description}}
{{/items}}
{{/interfaces}}

{{#dependencies}}
**Dependencies:**
{{#items}}
- [{{name}}](#{{anchor}}) - {{description}}
{{/items}}
{{/dependencies}}

{{/components}}

## Data Flow

{{#data_flows}}
### {{name}}

{{description}}

{{#diagram}}
```mermaid
{{diagram}}
```
{{/diagram}}

{{#steps}}
{{step_number}}. {{description}}
{{/steps}}

{{/data_flows}}

## Design Patterns

{{#patterns}}
### {{name}}

**Description:** {{description}}

**Implementation:** {{implementation}}

{{#example}}
**Example:**
```{{language}}
{{code}}
```
{{/example}}

**Benefits:**
{{#benefits}}
- {{benefit}}
{{/benefits}}

{{/patterns}}

## Architectural Decisions

{{#decisions}}
### {{title}}

**Date:** {{date}}

**Status:** {{status}}

**Context:**
{{context}}

**Decision:**
{{decision}}

**Consequences:**
{{#consequences}}
- {{consequence}}
{{/consequences}}

{{/decisions}}

## Security Architecture

{{#security}}
### {{component}}

{{description}}

{{#measures}}
- **{{type}}**: {{description}}
{{/measures}}

{{/security}}

## Performance Considerations

{{#performance}}
### {{area}}

{{description}}

{{#optimizations}}
- {{optimization}}
{{/optimizations}}

{{#metrics}}
**Key Metrics:**
- {{metric}}: {{target}}
{{/metrics}}

{{/performance}}

## Scalability

{{#scalability}}
### {{aspect}}

{{description}}

{{#strategies}}
- {{strategy}}
{{/strategies}}

{{/scalability}}

## Technology Stack

{{#tech_stack}}
### {{category}}

{{#technologies}}
- **{{name}}** ({{version}}) - {{purpose}}
{{/technologies}}

{{/tech_stack}}

## Future Considerations

{{#future}}
### {{area}}

{{description}}

{{#recommendations}}
- {{recommendation}}
{{/recommendations}}

{{/future}}