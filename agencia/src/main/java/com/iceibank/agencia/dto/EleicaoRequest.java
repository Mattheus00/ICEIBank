package com.iceibank.agencia.dto;

import jakarta.validation.constraints.NotNull;

import java.util.List;

public class EleicaoRequest {

    @NotNull
    private Integer idOrigem;

    @NotNull
    private List<Integer> vetor;

    public Integer getIdOrigem() {
        return idOrigem;
    }

    public void setIdOrigem(Integer idOrigem) {
        this.idOrigem = idOrigem;
    }

    public List<Integer> getVetor() {
        return vetor;
    }

    public void setVetor(List<Integer> vetor) {
        this.vetor = vetor;
    }
}
