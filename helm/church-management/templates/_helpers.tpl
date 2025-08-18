{{/*
Expand the name of the chart.
*/}}
{{- define "church-management.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "church-management.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "church-management.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "church-management.labels" -}}
helm.sh/chart: {{ include "church-management.chart" . }}
{{ include "church-management.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "church-management.selectorLabels" -}}
app.kubernetes.io/name: {{ include "church-management.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "church-management.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "church-management.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Database host
*/}}
{{- define "church-management.databaseHost" -}}
{{- if .Values.postgresql.enabled }}
{{- include "church-management.fullname" . }}-postgresql
{{- else if .Values.externalDatabase.enabled }}
{{- .Values.externalDatabase.host }}
{{- else }}
{{- "postgresql" }}
{{- end }}
{{- end }}

{{/*
Database port
*/}}
{{- define "church-management.databasePort" -}}
{{- if .Values.postgresql.enabled }}
{{- "5432" }}
{{- else if .Values.externalDatabase.enabled }}
{{- .Values.externalDatabase.port | toString }}
{{- else }}
{{- "5432" }}
{{- end }}
{{- end }}

{{/*
Database name
*/}}
{{- define "church-management.databaseName" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.database }}
{{- else if .Values.externalDatabase.enabled }}
{{- .Values.externalDatabase.database }}
{{- else }}
{{- "church_management" }}
{{- end }}
{{- end }}

{{/*
Database username
*/}}
{{- define "church-management.databaseUsername" -}}
{{- if .Values.postgresql.enabled }}
{{- .Values.postgresql.auth.username }}
{{- else if .Values.externalDatabase.enabled }}
{{- .Values.externalDatabase.username }}
{{- else }}
{{- "postgres" }}
{{- end }}
{{- end }}

{{/*
Database secret name
*/}}
{{- define "church-management.secretName" -}}
{{- if .Values.postgresql.enabled }}
{{- include "church-management.fullname" . }}-postgresql
{{- else }}
{{- include "church-management.fullname" . }}-database
{{- end }}
{{- end }}
