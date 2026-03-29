resource "aws_guardduty_detector" "this" {
  enable                       = var.enable
  finding_publishing_frequency = var.finding_publishing_frequency

  datasources {
    s3_logs {
      enable = var.enable_s3_protection
    }
    kubernetes {
      audit_logs {
        enable = var.enable_eks_protection
      }
    }
    malware_protection {
      scan_ec2_instance_with_findings {
        ebs_volumes {
          enable = var.enable_malware_protection
        }
      }
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Findings export to S3
# ---------------------------------------------------------------------------
resource "aws_guardduty_publishing_destination" "s3" {
  count = var.findings_s3_bucket != null ? 1 : 0

  detector_id     = aws_guardduty_detector.this.id
  destination_arn = "arn:aws:s3:::${var.findings_s3_bucket}"
  kms_key_arn     = var.findings_kms_key_arn
}

# ---------------------------------------------------------------------------
# Trusted IP set
# ---------------------------------------------------------------------------
resource "aws_guardduty_ipset" "trusted" {
  count = var.ipset_iplist_uri != null ? 1 : 0

  detector_id = aws_guardduty_detector.this.id
  name        = "trusted-ips"
  format      = "TXT"
  location    = var.ipset_iplist_uri
  activate    = true
}
