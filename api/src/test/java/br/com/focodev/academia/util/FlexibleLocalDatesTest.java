package br.com.focodev.academia.util;

import org.junit.jupiter.api.Test;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;

import static org.junit.jupiter.api.Assertions.*;

class FlexibleLocalDatesTest {

    @Test
    void parsesIsoAndBrazilianFormats() {
        LocalDate expected = LocalDate.of(1992, 6, 27);
        assertEquals(expected, FlexibleLocalDates.parse("1992-06-27"));
        assertEquals(expected, FlexibleLocalDates.parse("27/06/1992"));
        assertEquals(expected, FlexibleLocalDates.parse("27-06-1992"));
        assertEquals(expected, FlexibleLocalDates.parse("27061992"));
        assertEquals(expected, FlexibleLocalDates.parse("19920627"));
        assertNull(FlexibleLocalDates.parse(" "));
        assertNull(FlexibleLocalDates.parse(null));
    }

    @Test
    void rejectsInvalidDate() {
        assertThrows(DateTimeParseException.class, () -> FlexibleLocalDates.parse("2706199"));
        assertThrows(DateTimeParseException.class, () -> FlexibleLocalDates.parse("31/02/1992"));
        assertThrows(DateTimeParseException.class, () -> FlexibleLocalDates.parse("abc"));
    }
}
