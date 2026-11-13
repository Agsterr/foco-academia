package br.com.focodev.academia.util;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;

import static org.junit.jupiter.api.Assertions.*;

class FlexibleLocalDatesTest {

    @Test
    void parsesIsoAndBrazilianFormats() {
        LocalDate expected = LocalDate.of(1988, 3, 15);
        assertEquals(expected, FlexibleLocalDates.parse("1988-03-15"));
        assertEquals(expected, FlexibleLocalDates.parse("15/03/1988"));
        assertEquals(expected, FlexibleLocalDates.parse("15-03-1988"));
        assertEquals(expected, FlexibleLocalDates.parse("15031988"));
        assertEquals(expected, FlexibleLocalDates.parse("19880315"));
        assertNull(FlexibleLocalDates.parse(" "));
        assertNull(FlexibleLocalDates.parse(null));
    }

    @Test
    void rejectsInvalidDate() {
        assertThrows(DateTimeParseException.class, () -> FlexibleLocalDates.parse("1503198"));
        assertThrows(DateTimeParseException.class, () -> FlexibleLocalDates.parse("31/02/1988"));
        assertThrows(DateTimeParseException.class, () -> FlexibleLocalDates.parse("abc"));
    }
}
