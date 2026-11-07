{{- define "enterprisebot-demo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "enterprisebot-demo.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s" .Release.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "enterprisebot-demo.labels" -}}
app.kubernetes.io/name: {{ include "enterprisebot-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version }}
{{- end }}

{{- define "enterprisebot-demo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "enterprisebot-demo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
