package br.com.focodev.academia.domain;

import jakarta.persistence.*;
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

import java.util.UUID;

@Entity
@Table(name = "exercises")
@Getter
@Setter
@NoArgsConstructor
public class Exercise {

    @Id
    @GeneratedValue(strategy = GenerationType.UUID)
    private UUID id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "workout_id")
    private Workout workout;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "workout_day_id")
    private WorkoutDay workoutDay;

    @Column(nullable = false)
    private String name;

    @Column(length = 2000)
    private String description;

    private Integer sets;
    private Integer reps;
    private String duration;
    private String videoUrl;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 16)
    private MediaType mediaType = MediaType.NONE;

    @Column(length = 1000)
    private String variationNotes;

    private String notes;

    @Column(nullable = false)
    private int sortOrder;
}
