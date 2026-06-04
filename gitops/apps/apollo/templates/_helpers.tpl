{{- define "apollo.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "apollo.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{- define "apollo.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "apollo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "apollo.selectorLabels" -}}
app.kubernetes.io/name: {{ include "apollo.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "apollo.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (include "apollo.fullname" .) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "apollo.image" -}}
{{- printf "%s/%s:%s" .root.Values.global.imageRegistry .component.image.repository .component.image.tag -}}
{{- end -}}

{{- define "apollo.commonEnv" -}}
- name: TZ
  value: {{ .Values.global.timezone | quote }}
- name: JAVA_OPTS
  value: {{ .Values.global.javaOpts | quote }}
- name: SERVER_PORT
  value: {{ .port | quote }}
{{- end -}}

{{- define "apollo.eurekaEnv" -}}
- name: EUREKA_SERVICE_URL
  value: {{ .Values.internalDiscovery.eurekaUrl | quote }}
- name: EUREKA_CLIENT_SERVICEURL_DEFAULTZONE
  value: {{ .Values.internalDiscovery.eurekaUrl | quote }}
- name: EUREKA_INSTANCE_PREFER_IP_ADDRESS
  value: "true"
- name: EUREKA_INSTANCE_IP_ADDRESS
  valueFrom:
    fieldRef:
      fieldPath: status.podIP
{{- end -}}
