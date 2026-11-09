package br.com.focodev.academia.billing;

import org.springframework.boot.context.properties.ConfigurationProperties;

import java.util.List;

/**
 * Configuração da assinatura do aluno avulso.
 *
 * @param enforce            liga o bloqueio de treinos prontos/fichas próprias para quem não assina.
 *                           Desligado até os produtos existirem no Google Play Console.
 * @param trialDays          dias grátis ao criar a conta
 * @param productIds         IDs das assinaturas cadastradas no Play Console
 * @param googlePackageName  pacote do app na Play Store
 * @param googleServiceAccountJson JSON da conta de serviço com acesso à Google Play Developer API
 * @param academyMonthlyPrice     mensalidade da academia (R$), inclui todos os instrutores
 * @param academyIncludedStudents alunos incluídos na mensalidade da academia
 */
@ConfigurationProperties(prefix = "app.billing")
public record BillingProperties(
        boolean enforce,
        Integer trialDays,
        List<String> productIds,
        String googlePackageName,
        String googleServiceAccountJson,
        java.math.BigDecimal academyMonthlyPrice,
        Integer academyIncludedStudents
) {
    public java.math.BigDecimal academyMonthlyPriceOrDefault() {
        return academyMonthlyPrice != null ? academyMonthlyPrice : new java.math.BigDecimal("149.00");
    }

    public int academyIncludedStudentsOrDefault() {
        return academyIncludedStudents != null ? academyIncludedStudents : 100;
    }

    public int trialDaysOrDefault() {
        return trialDays != null ? trialDays : 7;
    }

    public List<String> productIdsOrDefault() {
        return productIds != null && !productIds.isEmpty()
                ? productIds
                : List.of("foco_premium_mensal", "foco_premium_anual");
    }

    public String packageNameOrDefault() {
        return googlePackageName != null && !googlePackageName.isBlank()
                ? googlePackageName
                : "com.focodev.academia.aluno";
    }
}
