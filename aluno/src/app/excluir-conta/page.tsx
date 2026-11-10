import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { LEGAL } from "@/lib/legal";

export const metadata: Metadata = { title: "Excluir conta — Foco Academia" };

/** URL de exclusão de conta e dados exigida na ficha da Play Store. */
export default function DeleteAccountPage() {
  const subject = encodeURIComponent("Excluir minha conta - Foco Academia");
  const body = encodeURIComponent(
    "Quero excluir minha conta do Foco Academia.\n\nE-mail da conta: \nNome: ",
  );
  return (
    <LegalPage title="Excluir conta e dados">
      <p>
        Para excluir sua conta do <strong>Foco Academia</strong> e os dados associados, envie um e-mail para{" "}
        <a href={`mailto:${LEGAL.email}?subject=${subject}&body=${body}`}>{LEGAL.email}</a> a partir do e-mail
        cadastrado na conta, com o assunto &quot;Excluir minha conta - Foco Academia&quot;.
      </p>

      <h2>O que é apagado</h2>
      <ul>
        <li>Dados da conta: nome, e-mail, telefone e senha.</li>
        <li>Treinos feitos, rotas de GPS, calorias, histórico e registros de peso.</li>
        <li>Aparelhos vinculados e preferências.</li>
      </ul>

      <h2>Prazo e exceções</h2>
      <p>
        Atendemos o pedido em até 15 dias. Podemos manter por mais tempo apenas o que a lei exigir (por exemplo,
        registros fiscais de uma assinatura). Se você assina o Foco Premium, cancele a assinatura na Google Play
        (Pagamentos e assinaturas) para não ser cobrado de novo.
      </p>
      <p>
        Se a sua conta foi criada por uma academia, a academia pode ter registros próprios sobre o seu vínculo; fale
        com ela também.
      </p>
    </LegalPage>
  );
}
