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
 * @param personalMonthlyPrice     mensalidade do personal autônomo (R$)
 * @param personalIncludedStudents alunos incluídos na mensalidade do personal
 * @param linkedProductIds  IDs das assinaturas de aluno vinculado a academia ou personal
 * @param freeEmails        e-mails que usam sem pagar
 */
@ConfigurationProperties(prefix = "app.billing")
public record BillingProperties(
        boolean enforce,
        Integer trialDays,
        List<String> productIds,
        String googlePackageName,
        String googleServiceAccountJson,
        java.math.BigDecimal academyMonthlyPrice,
        Integer academyIncludedStudents,
        java.math.BigDecimal personalMonthlyPrice,
        Integer personalIncludedStudents,
        List<String> linkedProductIds,
        List<String> freeEmails
) {
    /** Assinaturas (mais baratas) de aluno vinculado a academia ou personal. */
    public List<String> linkedProductIdsOrDefault() {
        return linkedProductIds != null && !linkedProductIds.isEmpty()
                ? linkedProductIds
                : List.of("foco_academia_aluno_mensal");
    }

    /** E-mails liberados sem pagar (testadores e revisor da loja). */
    public boolean isFreeEmail(String email) {
        return email != null && freeEmails != null
                && freeEmails.stream().anyMatch(free -> free.trim().equalsIgnoreCase(email.trim()));
    }

    /** Mensalidade conforme o tipo: academia ou personal autônomo. */
    public java.math.BigDecimal planMonthlyPrice(br.com.focodev.academia.domain.Academy academy) {
        if (academy.isPersonal()) {
            return personalMonthlyPrice != null ? personalMonthlyPrice : new java.math.BigDecimal("39.90");
        }
        return academyMonthlyPriceOrDefault();
    }

    public int planIncludedStudents(br.com.focodev.academia.domain.Academy academy) {
        if (academy.isPersonal()) {
            return personalIncludedStudents != null ? personalIncludedStudents : 30;
        }
        return academyIncludedStudentsOrDefault();
    }

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
                : List.of("foco_academia_mensal");
    }

    public String packageNameOrDefault() {
        return googlePackageName != null && !googlePackageName.isBlank()
                ? googlePackageName
                : "com.focodev.academia.aluno";
    }
}
