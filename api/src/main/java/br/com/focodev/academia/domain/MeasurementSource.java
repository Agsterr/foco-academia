package br.com.focodev.academia.domain;

public enum MeasurementSource {
    STUDENT,
    INSTRUCTOR,
    /** Balança digital via Bluetooth */
    SCALE_BLE,
    /** Dados vindos de relógio / importação de arquivo */
    WATCH,
    IMPORT
}
