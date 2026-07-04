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

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "workout_id")
    private Workout workout;

    @Column(nullable = false)
    private String name;

    @Column(length = 2000)
    private String description;

    private Integer sets;
    private Integer reps;
    private String duration;
    private String videoUrl;
    private String notes;

    @Column(nullable = false)
    private int sortOrder;
}
