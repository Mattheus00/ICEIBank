package com.iceibank.agencia.dto;

import jakarta.validation.constraints.NotNull;

import java.util.List;

public class CoordenadorRequest {

    @NotNull
    private Integer idLider;

    @NotNull
    private List<Integer> vetor;

    public Integer getIdLider() {
        return idLider;
    }

    public void setIdLider(Integer idLider) {
        this.idLider = idLider;
    }

    public List<Integer> getVetor() {
        return vetor;
    }

    public void setVetor(List<Integer> vetor) {
        this.vetor = vetor;
    }
}
