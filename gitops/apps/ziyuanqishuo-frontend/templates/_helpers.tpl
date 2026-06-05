{{- define "ziyuanqishuo-frontend.name" -}}
{{- .Chart.Name | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "ziyuanqishuo-frontend.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "ziyuanqishuo-frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "ziyuanqishuo-frontend.selectorLabels" -}}
app.kubernetes.io/name: {{ include "ziyuanqishuo-frontend.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}
