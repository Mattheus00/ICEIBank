package com.iceibank.agencia.model;

public class Conta {

    private int id;
    private String nomeAluno;
    private double saldo;

    public Conta() {}

    public Conta(int id, String nomeAluno, double saldo) {
        this.id = id;
        this.nomeAluno = nomeAluno;
        this.saldo = saldo;
    }

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getNomeAluno() {
        return nomeAluno;
    }

    public void setNomeAluno(String nomeAluno) {
        this.nomeAluno = nomeAluno;
    }

    public double getSaldo() {
        return saldo;
    }

    public void setSaldo(double saldo) {
        this.saldo = saldo;
    }
}
