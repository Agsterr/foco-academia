import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { LEGAL } from "@/lib/legal";

export const metadata: Metadata = { title: "Política de Privacidade — Foco Academia" };

/** URL exigida na ficha da Play Store e acessível dentro do app. */
export default function PrivacyPage() {
  return (
    <LegalPage title="Política de Privacidade">
      <p>Última atualização: {LEGAL.updatedAt}</p>
      <p>
        Esta política explica como {LEGAL.company} trata dados pessoais no site e no aplicativo{" "}
        <strong>Foco Academia</strong>, em conformidade com a Lei Geral de Proteção de Dados (Lei 13.709/2018).
      </p>

      <h2>Dados que coletamos</h2>
      <ul>
        <li>
          <strong>Conta:</strong> nome, e-mail, telefone (opcional) e senha, que é guardada apenas como hash
          criptográfico.
        </li>
        <li>
          <strong>Treinos:</strong> fichas, exercícios realizados, séries, tempos, calorias e histórico.
        </li>
        <li>
          <strong>Saúde e corpo (opcional):</strong> peso e evolução do peso que você registra, inclusive por balança
          Bluetooth quando você conecta uma.
        </li>
        <li>
          <strong>Localização:</strong> somente durante o <em>treino outdoor</em>, depois que você inicia a gravação,
          para registrar a rota, a distância e o ritmo. O app não coleta localização fora do treino.
        </li>
        <li>
          <strong>Aparelho:</strong> identificador do aparelho, usado para limitar cada conta a um aparelho por vez
          (segurança da conta).
        </li>
        <li>
          <strong>Assinatura:</strong> o estado da assinatura Foco Premium é confirmado com a Google Play. Não
          recebemos nem guardamos dados de cartão.
        </li>
      </ul>
      <p>
        Não vendemos dados, não usamos identificador de publicidade e o app não exibe anúncios nem faz rastreamento
        entre apps e sites de terceiros.
      </p>

      <h2>Para que usamos</h2>
      <ul>
        <li>Exibir seus treinos, registrar o progresso e calcular estatísticas (execução de contrato).</li>
        <li>Gravar e mostrar a rota do treino outdoor (consentimento, pela permissão de localização).</li>
        <li>Permitir que academias e instrutores acompanhem os alunos vinculados a eles (execução de contrato).</li>
        <li>Segurança da conta e prevenção de fraudes (legítimo interesse).</li>
      </ul>

      <h2>Compartilhamento</h2>
      <p>
        Se você é aluno de uma academia ou de um personal, a academia e o instrutor vinculados à sua conta veem seus
        treinos e sua evolução.
        Compartilhamos dados apenas com provedores de infraestrutura (hospedagem e armazenamento de arquivos) sob
        contrato e quando exigido por lei. Toda comunicação usa conexão criptografada (HTTPS).
      </p>

      <h2>Armazenamento no aparelho</h2>
      <p>
        O app guarda no aparelho o token de acesso em armazenamento seguro do sistema (Keystore) e, temporariamente,
        os pontos do GPS de um treino em andamento para não perder a rota caso o app feche.
      </p>

      <h2>Retenção e exclusão</h2>
      <p>
        Mantemos seus dados enquanto sua conta existir. Você pode pedir a exclusão da conta e dos dados associados em{" "}
        <a href="/excluir-conta">/excluir-conta</a>; atendemos em até 15 dias.
      </p>

      <h2>Seus direitos</h2>
      <p>
        Você pode solicitar confirmação, acesso, correção, anonimização, portabilidade e exclusão dos seus dados, bem
        como revogar consentimentos (art. 18 da LGPD), pelo e-mail <strong>{LEGAL.email}</strong>.
      </p>

      <h2>Crianças</h2>
      <p>O aplicativo não é direcionado a menores de 13 anos.</p>

      <h2>Contato</h2>
      <p>
        Encarregado de dados (DPO): {LEGAL.company} — {LEGAL.email}
      </p>
    </LegalPage>
  );
}
