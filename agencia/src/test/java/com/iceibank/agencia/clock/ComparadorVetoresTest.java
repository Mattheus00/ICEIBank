package com.iceibank.agencia.clock;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

class ComparadorVetoresTest {

    @Test
    void iguais() {
        assertEquals("IGUAIS", ComparadorVetores.comparar(new int[]{1, 2, 3}, new int[]{1, 2, 3}));
    }

    @Test
    void antes() {
        assertEquals("ANTES", ComparadorVetores.comparar(new int[]{3, 1, 0}, new int[]{3, 2, 0}));
    }

    @Test
    void concorrentes() {
        assertEquals("CONCORRENTES", ComparadorVetores.comparar(new int[]{3, 1, 0}, new int[]{1, 3, 0}));
    }

    @Test
    void validaTamanho() {
        assertThrows(IllegalArgumentException.class, () -> ComparadorVetores.validarECopiar(List.of(1, 2)));
    }
}
