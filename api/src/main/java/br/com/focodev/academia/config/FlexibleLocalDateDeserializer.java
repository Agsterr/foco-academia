package br.com.focodev.academia.config;

import br.com.focodev.academia.util.FlexibleLocalDates;
import com.fasterxml.jackson.core.JsonParser;
import com.fasterxml.jackson.databind.DeserializationContext;
import com.fasterxml.jackson.databind.JsonDeserializer;

import java.io.IOException;
import java.time.LocalDate;
import java.time.format.DateTimeParseException;

public class FlexibleLocalDateDeserializer extends JsonDeserializer<LocalDate> {

    @Override
    public Class<?> handledType() {
        return LocalDate.class;
    }

    @Override
    public LocalDate deserialize(JsonParser parser, DeserializationContext context) throws IOException {
        String text = parser.getValueAsString();
        try {
            return FlexibleLocalDates.parse(text);
        } catch (DateTimeParseException ex) {
            return (LocalDate) context.handleWeirdStringValue(
                    LocalDate.class,
                    text,
                    "Data inválida. Use AAAA-MM-DD ou DD/MM/AAAA."
            );
        }
    }
}
