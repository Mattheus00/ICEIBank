package com.iceibank.agencia.dto;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

public class CreditoRemotoRequest {

    @NotNull
    @Positive
    private Double valor;

    @NotNull
    private Integer timestampLamport;

    @NotNull
    private Integer origemAgencia;

    public Double getValor() {
        return valor;
    }

    public void setValor(Double valor) {
        this.valor = valor;
    }

    public Integer getTimestampLamport() {
        return timestampLamport;
    }

    public void setTimestampLamport(Integer timestampLamport) {
        this.timestampLamport = timestampLamport;
    }

    public Integer getOrigemAgencia() {
        return origemAgencia;
    }

    public void setOrigemAgencia(Integer origemAgencia) {
        this.origemAgencia = origemAgencia;
    }
}
