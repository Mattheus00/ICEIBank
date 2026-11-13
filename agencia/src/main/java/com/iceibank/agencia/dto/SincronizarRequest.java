package com.iceibank.agencia.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

import java.util.List;

public class SincronizarRequest {

    @NotBlank
    private String tipo;

    @NotNull
    @Positive
    private Double valor;

    @NotNull
    private List<Integer> vetorConhecido;

    private String operacaoId;

    public String getTipo() {
        return tipo;
    }

    public void setTipo(String tipo) {
        this.tipo = tipo;
    }

    public Double getValor() {
        return valor;
    }

    public void setValor(Double valor) {
        this.valor = valor;
    }

    public List<Integer> getVetorConhecido() {
        return vetorConhecido;
    }

    public void setVetorConhecido(List<Integer> vetorConhecido) {
        this.vetorConhecido = vetorConhecido;
    }

    public String getOperacaoId() {
        return operacaoId;
    }

    public void setOperacaoId(String operacaoId) {
        this.operacaoId = operacaoId;
    }
}
