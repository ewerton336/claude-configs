---
name: leilao-imovel-analysis
description: Use esta skill sempre que o usuário enviar links de leilão de imóvel, PDFs de edital/matrícula/processo, ou pedir análise de oportunidade em leilão imobiliário no Brasil. Produz uma análise em português no padrão aprovado: breve, objetiva, com resumo de custos/gastos, riscos, oportunidade e conclusão direta sobre se vale ou não a pena. Acione mesmo que o usuário diga apenas “analise esse leilão”, “vale a pena?”, “resuma os custos”, “vou mandar links de leilão” ou envie links de leiloeiro/PDFs relacionados.
---

# Análise de Leilão Imobiliário

Use esta skill para analisar leilões imobiliários brasileiros a partir de uma página de leilão e documentos relacionados, como edital, matrícula, laudo, autos do processo, certidões, débitos de condomínio/IPTU e anexos do leiloeiro.

O objetivo é entregar ao usuário uma visão prática de investimento: quanto pode custar, quais são os riscos reais, qual é a oportunidade e se vale ou não a pena entrar.

## Fluxo de trabalho

1. **Coletar dados da página e documentos**
   - Abrir a página do leilão quando possível.
   - Ler PDFs/documentos relacionados.
   - Se a página estiver protegida por Cloudflare ou inacessível, priorizar os PDFs/anexos e informar a limitação de forma breve.
   - Para PDFs, extrair texto com `Read` quando possível; se falhar, usar ferramenta/CLI disponível para extração, sem instalar nada permanente salvo necessidade clara.

2. **Extrair informações essenciais**
   - Tipo de imóvel.
   - Endereço e bairro/cidade.
   - Área útil, comum e total.
   - Matrícula e cartório.
   - Processo judicial/vara/tribunal, se houver.
   - Natureza do leilão: judicial, extrajudicial, trabalhista, cível, alienação fiduciária etc.
   - O que exatamente está sendo vendido: imóvel inteiro, fração ideal, nua-propriedade, direitos aquisitivos, parte de herança, copropriedade etc.
   - Avaliação, lance mínimo, 1ª/2ª praça, datas, formas de pagamento.
   - Comissão do leiloeiro.
   - Débitos informados: condomínio, IPTU, tributários, taxas, ônus, penhoras, indisponibilidades, hipotecas.
   - Ocupação/posse e responsabilidade pela desocupação.

3. **Calcular custos prováveis**
   - Lance mínimo ou lance provável.
   - Comissão do leiloeiro, geralmente 5%, se informado.
   - Entrada/sinal e saldo, se parcelado ou à vista.
   - ITBI estimado, deixando claro que depende da prefeitura/base de cálculo.
   - Registro/carta de arrematação/escritura/averbações, em faixa estimada quando não houver valor exato.
   - Condomínio e IPTU vencidos ou risco de débitos atualizados.
   - Custos jurídicos/despachante quando houver risco relevante.
   - Custos de desocupação, ação judicial, regularização ou negociação com coproprietários quando aplicável.

4. **Avaliar riscos de forma prática**
   Dê peso alto para riscos que reduzem liquidez ou uso real do imóvel:
   - Fração ideal ou copropriedade minoritária.
   - Imóvel ocupado.
   - Arrematação de direitos, não propriedade plena.
   - Indisponibilidade, penhoras ou ônus complexos.
   - Débitos condominiais/IPTU não atualizados.
   - Leilão judicial com possibilidade de impugnação, embargos, remição ou recurso.
   - Imóvel sem fotos, sem vistoria interna ou com descrição incompleta.
   - Divergência entre área/endereço/matrícula/anúncio.

5. **Determinar oportunidade**
   - Compare lance mínimo + custos com avaliação e valor de mercado quando houver dados suficientes.
   - Se não houver valor de mercado confiável, diga isso e avalie pelo desconto aparente e pela liquidez.
   - Para fração ideal, explique que a avaliação é muitas vezes teórica e a liquidez real é bem menor.
   - Diferencie oportunidade para comprador comum vs. investidor experiente.

## Formato de resposta

Responda em português, direto e no padrão abaixo. Mantenha a análise breve, mas completa o suficiente para decisão inicial.

```markdown
## Análise breve do leilão

**Imóvel:** ...  
**Área:** ...  
**Matrícula:** ...  
**Processo:** ...  
**O que está sendo vendido:** ...

## Valores principais

| Item | Valor estimado |
|---|---:|
| Avaliação | R$ ... |
| Lance mínimo | R$ ... |
| Comissão do leiloeiro | R$ ... |
| Entrada/sinal, se aplicável | R$ ... |
| Saldo, se aplicável | R$ ... |
| Desembolso inicial mínimo | R$ ... |
| Total mínimo sem taxas extras | R$ ... |

## Custos e gastos prováveis

Além do lance e comissão, considere:

- **ITBI:** ...
- **Registro/carta/escritura:** ...
- **Certidões, protocolo e averbações:** ...
- **Advogado/despachante:** ...
- **Condomínio:** ...
- **IPTU:** ...
- **Custos futuros ou de regularização:** ...

Estimativa realista de custo total inicial: **R$ ... a R$ ...**, podendo variar conforme ...

## Pontos positivos

- ...
- ...

## Principais riscos

O maior problema é: **...**

Isso significa que você provavelmente:

- ...
- ...

## Oportunidade

...

## Conclusão: vale a pena?

**Para comprador comum, ...**  
**Para investidor experiente, ...**

Minha conclusão prática: **...**
```

## Regras de julgamento

- Seja claro quando o imóvel não é integral. Isso costuma ser o fator decisivo.
- Não trate desconto nominal como oportunidade real se houver fração ideal, ocupação ou baixa liquidez.
- Quando os dados forem incompletos, não invente valores; use faixas e diga o que precisa confirmar.
- A conclusão deve ser direta: “vale”, “não vale”, “só vale se...”, ou “eu evitaria acima de...”.
- Evite juridiquês excessivo. Traduza o impacto prático para o usuário.
- Não diga que é parecer jurídico. Pode recomendar validação com advogado quando houver risco relevante.

## Checklist antes da conclusão

Antes de concluir, confirme se mencionou:

- O que exatamente está sendo comprado.
- Lance mínimo + comissão.
- Estimativa de custo total inicial.
- Débitos/ônus conhecidos.
- Ocupação ou posse, se constar.
- Risco principal.
- Perfil para quem faria sentido.
- Conclusão objetiva de vale ou não a pena.
