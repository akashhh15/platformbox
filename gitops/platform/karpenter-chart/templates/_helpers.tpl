{{/* Required cluster identity values. Failing early keeps a wrong IAM role
     or discovery tag from being applied to a real EKS cluster. */}}
{{- define "karpenter-nodepools.clusterName" -}}
{{- required "clusterName must be the EKS cluster name (project-environment)" .Values.clusterName -}}
{{- end -}}

{{- define "karpenter-nodepools.environment" -}}
{{- required "environment must be dev, staging or prod" .Values.environment -}}
{{- end -}}

{{- define "karpenter-nodepools.nodeRoleArn" -}}
{{- required "nodeRoleArn must be the Terraform karpenter_node_role_arn output" .Values.nodeRoleArn -}}
{{- end -}}

{{- define "karpenter-nodepools.tags" -}}
Project: {{ .Values.project | quote }}
Environment: {{ include "karpenter-nodepools.environment" . | quote }}
ManagedBy: {{ .Values.managedBy | quote }}
Owner: {{ .Values.owner | quote }}
{{- end -}}
