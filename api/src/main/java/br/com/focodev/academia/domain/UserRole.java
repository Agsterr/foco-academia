package br.com.focodev.academia.domain;

public enum UserRole {
    ADMIN,
    INSTRUTOR,
    ALUNO,
    /** Dono/gerente da academia: vê instrutores, alunos, desempenho e reclamações. */
    GESTOR
}
