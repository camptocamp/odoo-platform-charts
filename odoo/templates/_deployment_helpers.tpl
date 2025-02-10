{{- define "odoo.deployment.replicas" -}}
{{- if .Values.replicaCount -}}
  {{- if eq .pod_type "cron" -}}
1
  {{- else -}}
{{ .Values.replicaCount }}
  {{- end -}}
{{- else -}}
0
{{- end -}}
{{- end -}}

{{- define "odoo.deployment.defaultComponent" -}}
{{- if eq .Values.odoo.mode "workers" -}}
worker
{{- else -}}
thread
{{- end -}}
{{- end -}}

{{- define "odoo.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "odoo.name" . }}-{{ .pod_type }}
  labels:
    {{- include "odoo.labels" . | nindent 4 }}
spec:
  replicas: {{ include "odoo.deployment.replicas" . }}
  strategy:
    {{- if or (hasSuffix "-roll" .Values.image.odoo.tag) .Values.rollingupdatechart }}
    type: RollingUpdate
    {{- else }}
    type: Recreate
    {{- end }}
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      {{- include "odoo.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: "odoo-{{ .pod_type }}"
  template:
    metadata:
      annotations:
        config-hash-odoo: {{ include (print $.Template.BasePath "/config-odoo.yaml") $ | sha256sum | trunc 63 }}
        config-hash-nginx: {{ include (print $.Template.BasePath "/config-nginx.yaml") $ | sha256sum | trunc 63 }}
        config-hash-secret: {{ include (print $.Template.BasePath "/config-odoo-secret.yaml") $ | sha256sum | trunc 63 }}
        config-hash-healthz: {{ include (print $.Template.BasePath "/config-odoo-healthz.yaml") $ | sha256sum | trunc 63 }}
        {{- with .Values.additionalAnnotations }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "odoo.labels" $ | nindent 8 }}
        app: {{ template "odoo.name" . }}
        app.kubernetes.io/component: "odoo-{{ .pod_type }}"
        release: "{{ .Release.Name }}"
        {{- include "odoo.selectorLabels" . | nindent 8 }}
        {{- with .Values.additionalLabels }}
          {{- toYaml . | nindent 8 }}
        {{- end }}
    spec:
      serviceAccountName: {{ .Values.serviceAccountName }}
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.securityContext.odoo }}
      securityContext:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.odoo.marabunta.enabled }}
      initContainers:
        {{- if or (eq .Values.odoo.env "prod") .Values.odoo.marabunta.force_backup }}
        - name: marabunta-setup
          image: "{{ .Values.image.odoo.repository }}:{{ .Values.image.odoo.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          command: ['cp', '/odoo/migration.yml', '/tmp/migration.yml']
          volumeMounts:
            - name: marabunta-tmp
              mountPath: "/tmp"
        - name: preinit-manager
          image: "{{ .Values.image.preinit_manager.repository }}:{{ .Values.image.preinit_manager.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          volumeMounts:
            - name: marabunta-tmp
              mountPath: "/tmp"
          env:
            {{- include "odoo.common-environment" . | nindent 12 }}
          envFrom:
            - configMapRef:
                name: preinit-manager-config{{- include "odoo-cs-suffix" . }}
        {{- end }}
        - name: marabunta-migration
          image: "{{ .Values.image.odoo.repository }}:{{ .Values.image.odoo.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          {{- if .Values.image.odoo.is_old_image_flavour }}
          command: ['sh', '-c', "docker-entrypoint.sh gosu odoo migrate"]
          {{- else }}
          command: ['sh', '-c', "docker-entrypoint.sh migrate"]
          {{- end }}
          env:
            - name: LIMIT_MEMORY_SOFT
              value: "1300234240"
            {{- include "odoo.common-environment" . | nindent 12 }}
          envFrom:
            - configMapRef:
                name: odoo-config{{- include "odoo-cs-suffix" . }}
            - secretRef:
                name: odoo-secret{{- include "odoo-cs-suffix" . }}
                optional: true
      {{- end }}
      containers:
        - name: odoo
          image: "{{ .Values.image.odoo.repository }}:{{ .Values.image.odoo.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          {{- if not .Values.image.odoo.is_old_image_flavour }}
          command: ['sh', '-c', "docker-entrypoint.sh odoo {{ printf "--load=%s" (.Values.odoo.server_wide_modules | default "web,attachment_azure,session_redis,logging_json") }}"]
          {{- end }}
          env:
            {{- if eq .pod_type "cron" }}
            - name: MAX_CRON_THREADS
              value: "1"
            {{- else if eq .pod_type "thread" }}
            - name: WORKERS
              value: "0"
            - name: MAX_CRON_THREADS
              value: "0"
            - name: ODOO_MAX_HTTP_THREADS
              value: "True"
            {{- end }}
          {{- include "odoo.common-environment" . | nindent 12 }}
          envFrom:
            - configMapRef:
                name: odoo-config{{- include "odoo-cs-suffix" . }}
            - secretRef:
                name: odoo-secret{{- include "odoo-cs-suffix" . }}
                optional: true
          ports:
            - containerPort: 8069
              name: odoo
            - containerPort: 8072
              name: longpolling
          {{- with .Values.odoo.livenessProbe }}
          livenessProbe:
              {{- toYaml . | nindent 14 }}
           {{- end }}
          {{- with .Values.odoo.readinessProbe }}
          readinessProbe:
              {{- toYaml . | nindent 14 }}
          {{- end }}
          {{- with .Values.odoo.startupProbe }}
          startupProbe:
              {{- toYaml . | nindent 14 }}
           {{- end }}
          {{- with .Values.volumeMounts }}
          {{- if .odoo }}
          volumeMounts:
            {{- toYaml .odoo | nindent 12 }}
          {{- end }}
          {{- end }}
          resources:
          {{- include "odoo.physical-resources" . | nindent 12 }}
        - name: nginx
          image: "{{ .Values.image.nginx.repository }}:{{ .Values.image.nginx.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          envFrom:
            - configMapRef:
                name: nginx-config{{- include "odoo-cs-suffix" . }}
          resources:
            {{- toYaml .Values.resources.nginx | nindent 12 }}
          ports:
            - containerPort: 80
              name: http
        - name: odoohealthz
          image: "{{ .Values.image.odoohealthz.repository }}:{{ .Values.image.odoohealthz.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          env:
            {{- include "odoo.common-environment" . | nindent 12 }}
          envFrom:
            - configMapRef:
                name: odoo-config{{- include "odoo-cs-suffix" . }}
            - configMapRef:
                name: odoohealthz-config{{- include "odoo-cs-suffix" . }}
          resources:
            {{- toYaml .Values.resources.odoohealthz | nindent 12 }}
          {{- with .Values.volumeMounts }}
          {{- if .odoo }}
          volumeMounts:
            {{- toYaml .odoo | nindent 12 }}
          {{- end }}
          {{- end }}
          ports:
            - containerPort: 8080
              name: odoohealthz
      volumes:
        - name: marabunta-tmp
          emptyDir: {}
        {{- with .Values.volumes }}
        {{- if .odoo }}
        {{- toYaml .odoo | nindent 8 }}
        {{- end }}
        {{- end }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- if .Values.spreadOdooPodsOverNodes.enabled }}
      topologySpreadConstraints:
        - labelSelector:
            matchLabels:
              app: {{ template "odoo.name" . }}
              release: "{{ .Release.Name }}"
          maxSkew: {{ .Values.spreadOdooPodsOverNodes.maxSkew }}
          topologyKey: {{ .Values.spreadOdooPodsOverNodes.topologyKey }}
          whenUnsatisfiable: {{ .Values.spreadOdooPodsOverNodes.whenUnsatisfiable }}
      {{- end }}
---
apiVersion: v1
kind: Service
metadata:
  name: {{ include "odoo.fullname" . }}-{{ .pod_type }}
  labels:
    {{- include "odoo.labels" $ | nindent 4 }}
spec:
  ports:
    - port: 80
      targetPort: http
  selector:
    {{- include "odoo.selectorLabels" . | nindent 4 }}
    app.kubernetes.io/component: "odoo-{{ .pod_type }}"
---
{{- end -}}
