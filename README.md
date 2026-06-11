# Relatório de Tratamento de Erros

## Visão Geral

O aplicativo realiza requisições HTTP para duas APIs públicas:

- **ViaCEP** (`viacep.com.br`) — consulta de endereço por CEP
- **JSONPlaceholder** (`jsonplaceholder.typicode.com`) — listagem de posts

Ambas as chamadas usam o mesmo padrão de tratamento de erros com `try-catch`, cobrindo três cenários principais.

---

## Erros Tratados

### 1. `TimeoutException` — Tempo limite excedido

**Por que é importante:**  
Redes móveis podem ser lentas ou instáveis. Sem um timeout, o app ficaria esperando indefinidamente, congelando a tela do usuário sem nenhum feedback.

**Como é tratado no código:**
```dart
response = await http.get(uri).timeout(const Duration(seconds: 10));
} on TimeoutException {
  throw Exception('Tempo limite excedido. Verifique sua conexão.');
}
```

**Como o usuário é informado:**  
Na tela de CEP, a mensagem *"Tempo limite excedido. Verifique sua conexão."* aparece em um container vermelho. Na tela de Posts, a mesma mensagem ocupa o centro da tela com um ícone de Wi-Fi desligado e um botão "Tentar novamente".

**Situação real no app:**  
O usuário abre o app em um ambiente com sinal fraco. A requisição ao ViaCEP ultrapassa os 10 segundos configurados.

**O que aconteceria sem o tratamento:**  
O `FutureBuilder` travaria no estado `waiting` para sempre — o `CircularProgressIndicator` nunca pararia de girar.

---

### 2. Erro de conexão — Sem internet (`SocketException` / `ClientException`)

**Por que é importante:**  
É o erro mais comum em aplicativos móveis. O usuário pode estar em modo avião, em área sem sinal ou ter desligado o Wi-Fi. Sem tratamento, o app encerraria com uma exceção não tratada.

**Como é tratado no código:**  
O código usa um `catch (e)` genérico, que captura qualquer exceção de conexão que passar pelo filtro do `TimeoutException`. Em Android/iOS essa exceção é um `SocketException` (de `dart:io`); no Chrome é um `ClientException` (de `package:http`). O `catch (e)` cobre os dois casos sem depender de uma lib específica de plataforma:

```dart
} on TimeoutException {
  throw Exception('Tempo limite excedido. Verifique sua conexão.');
} catch (e) {
  // SocketException no Android, ClientException no Chrome
  throw Exception('Sem conexão com a internet.');
}
```

**Como o usuário é informado:**  
A mensagem *"Sem conexão com a internet."* aparece no container vermelho (CEP) ou na tela de erro central (Posts). Na tela de Posts há um botão "Tentar novamente"; na tela de CEP, o usuário pressiona "Buscar" novamente após reconectar.

**Situação real no app:**  
O usuário digita o CEP e pressiona "Buscar" com o celular em modo avião ativo. O `http.get()` falha imediatamente antes de abrir qualquer conexão.

**O que aconteceria sem o tratamento:**  
O app encerraria com uma mensagem de erro técnica do sistema, sem nenhuma explicação amigável.

---

### 3. Status HTTP diferente de 200 — Resposta de erro do servidor

**Por que é importante:**  
Mesmo com conexão, o servidor pode responder com `404 Not Found` ou `500 Internal Server Error`. O pacote `http` não lança exceção nesses casos — ele retorna normalmente com o código no `statusCode`. Por isso é necessário verificar manualmente.

**Como é tratado no código:**
```dart
if (response.statusCode != 200) {
  throw Exception('Erro do servidor: ${response.statusCode}');
}
```

**Como o usuário é informado:**  
A mensagem exibida é *"Erro do servidor: [código]"*, por exemplo *"Erro do servidor: 404"*.

**Situação real no app:**  
O endpoint do JSONPlaceholder `/posts` responde com `503 Service Unavailable`. Sem verificar o status, o app tentaria fazer `jsonDecode()` em um corpo HTML de erro e quebraria com um `FormatException`.

**O que aconteceria sem o tratamento:**  
O app apresentaria um crash com mensagem técnica incompreensível, ou exibiria dados corrompidos na lista.

---

### Bônus: CEP inválido — Validação local + resposta da ViaCEP

**Por que é importante:**  
Enviar uma string com menos de 8 dígitos ou com letras causaria um erro na API. Validar antes evita requisições desnecessárias.

**Como é tratado no código:**
```dart
// Validação local antes de chamar a API
if (cep.length != 8 || int.tryParse(cep) == null) {
  setState(() => _erro = 'O CEP deve ter exatamente 8 dígitos numéricos.');
  return;
}

// Verificação da resposta da ViaCEP
if (json.containsKey('erro')) {
  throw Exception('CEP não encontrado.');
}
```

**Como o usuário é informado:**  
Para entrada inválida: *"O CEP deve ter exatamente 8 dígitos numéricos."* — exibido instantaneamente, sem requisição. Para CEP inexistente: *"CEP não encontrado."* — exibido após a resposta da API.

---

## Resumo

| Erro | Como é capturado | Mensagem ao usuário | Retry |
|---|---|---|---|
| `TimeoutException` | `on TimeoutException` | Tempo limite excedido | Sim (Posts) / Buscar novamente (CEP) |
| Sem conexão | `catch (e)` genérico | Sem conexão com a internet | Sim (Posts) / Buscar novamente (CEP) |
| Status != 200 | `if (statusCode != 200)` | Erro do servidor: [código] | Sim |
| `{"erro": true}` (ViaCEP) | `if (json.containsKey('erro'))` | CEP não encontrado | Não |
| Entrada inválida | Validação local | 8 dígitos numéricos | Não |